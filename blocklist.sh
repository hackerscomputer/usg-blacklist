#!/bin/bash
{
echo "Blocklist update started"
}  > /config/scripts/blocklist-processing.txt

real_list=$(grep -B2 "FireHOL" /config/config.boot | head -n 1 | awk '{print $2}')
[[ -z "$real_list" ]] && { echo "aborting"; exit 1; } || echo "Will update FireHOL list ID $real_list"

ipset_list="temporary-list"

usgupt=$(uptime | awk '{print $4}')

backupexists="/config/scripts/blocklist-backup.bak"

if [ -e $backupexists ]
then
	backupexists="TRUE"
else
	backupexists="FALSE"
fi

process_blocklist () {
    /sbin/ipset -! destroy $ipset_list
    /sbin/ipset create $ipset_list hash:net

    tmpfile=$(mktemp /tmp/ipsetlist.XXXXXX)

    for url in https://iplists.firehol.org/files/firehol_level1.netset https://iplists.firehol.org/files/firehol_level2.netset https://iplists.firehol.org/files/iblocklist_onion_router.netset https://iplists.firehol.org/files/ciarmy.ipset https://iplists.firehol.org/files/tor_exits.ipset
    do
        echo "Fetching and processing $url"
        {
            echo "Processing blocklist"
            date
            echo $url
        } >> /config/scripts/blocklist-processing.txt
        
        curl -s "$url" | awk '/^[1-9]/ { print $1 }' | while read -r ip; do
            # Check if the IP is within any private IP ranges
            if [[ $ip == 192.168.* ]] || [[ $ip == 10.* ]] || [[ $ip =~ ^172\.1[6-9]\. ]] || [[ $ip =~ ^172\.2[0-9]\. ]] || [[ $ip =~ ^172\.3[0-1]\. ]]; then
                echo "Skipping $ip (within private IP ranges)"
                continue
            fi
            # Add IP to temp file
            echo "add $ipset_list $ip" >> "$tmpfile"
        done
    done

    if [ ! -s "$tmpfile" ]; then
        echo "Temporary list is empty, not backing up or swapping list. Leaving current list and contents in place."
        {
            echo "Temporary list is empty, not backing up or swapping list. Leaving current list and contents in place."
            date
        } >> /config/scripts/blocklist-processing.txt
    else
    	echo "Avvio restore ipset..."
    	# Avvio del timer
	start=$(date +%s%N)
        /sbin/ipset -exist restore -f "$tmpfile"
	# Fine del timer
	end=$(date +%s%N)
 	echo "Tempo di esecuzione: $((($end - $start) / 1000000)) ms"
        /sbin/ipset save $ipset_list -f /config/scripts/blocklist-backup.bak
        /sbin/ipset swap $ipset_list "$real_list"
        echo "Blocklist is updated and backed up"
        {
            echo "Blocklist is updated and backed up"
            date
        } >> /config/scripts/blocklist-processing.txt
    fi

    {
        echo "Blocklist contents"
        /sbin/ipset list -s "$real_list"
    } >> /config/scripts/blocklist-processing.txt

    # Clean up the temporary file
    rm -f "$tmpfile"
	
<<Disabled
	if [ "$usgupt" != "min," ] && [ "$backupexists" == "TRUE" ]
	then
		echo "Processing changes compared to previous run"
		echo "To see the changes check the log located at /config/scripts/blocklist-processing.txt"
		{
		echo "Blocklist changes compared to previous run"
		} >> /config/scripts/blocklist-processing.txt
		
		for Nip in $(/sbin/ipset list "$real_list" | awk '/^[1-9]/ { print }')
		do
			NTotal=$((NTotal+1));
			
			if ! /sbin/ipset test $ipset_list "$Nip"
			then
				NChanges=$((NChanges+1));
				{
				echo "ADDED $Nip to the list"
				} >> /config/scripts/blocklist-processing.txt
			else
				NoneAdded=$((NoneAdded+1));
			fi
		done
		
		for Oip in $(/sbin/ipset list $ipset_list | awk '/^[1-9]/ { print }')
		do
			OTotal=$((OTotal+1));
			
			if ! /sbin/ipset test "$real_list" "$Oip"
			then
				OChanges=$((OChanges+1));
				{
				echo "REMOVED $Oip from the list"
				} >> /config/scripts/blocklist-processing.txt
			else
				NoneRemoved=$((NoneRemoved+1));
			fi
		done
		
		if [ $((NTotal + OTotal)) == $((NoneAdded + NoneRemoved)) ]
		then
			{
			echo "No changes"
			} >> /config/scripts/blocklist-processing.txt
		else
			TChanges=$((NChanges + OChanges));
			{
			echo "$NChanges additions"
			echo "$OChanges removals"
			echo "$TChanges total changes"
			} >> /config/scripts/blocklist-processing.txt
		fi
		
		echo "Blocklist comparison complete"
		{
		echo "Blocklist comparison complete"
		} >> /config/scripts/blocklist-processing.txt
	fi
Disabled
		
	{
	echo "Blocklist processing finished"
	date
	} >> /config/scripts/blocklist-processing.txt

 	logger -p local7.debug "$(date) Blocklist processing finished"
 
	/sbin/ipset destroy $ipset_list
	echo "Blocklist processing finished"
}

if [ "$usgupt" == "min," ] && [ "$backupexists" = "TRUE" ]
then
	echo "USG uptime is less than one hour, and backup list is found" 
	echo "Loading previous version of blocklist. This will speed up provisioning"
	{
	echo "USG uptime is less than one hour, and backup list is found" 
	echo "Loading previous version of blocklist. This will speed up provisioning"
	date
	} >> /config/scripts/blocklist-processing.txt
	/sbin/ipset restore -f /config/scripts/blocklist-backup.bak
	/sbin/ipset swap $ipset_list "$real_list"
	/sbin/ipset -! destroy $ipset_list
	{
	echo "Blocklist contents"
	/sbin/ipset list -s "$real_list"
	echo "Restoration of blocklist backup complete"
	date
	} >> /config/scripts/blocklist-processing.txt
	echo "Restoration of blocklist backup complete"
elif [ "$usgupt" == "min," ] && [ "$backupexists" == "FALSE" ]
then
	echo "USG uptime is less than one hour, but backup list is not found"
	echo "Proceeding to create new blocklist. This will delay provisioning, but ensure you are protected"
	echo "Blocklist changes will not be compared as this is the first creation of the list"
	{
	echo "USG uptime is less than one hour, but backup list is not found"
	echo "Proceeding to create new blocklist. This will delay provisioning, but ensure you are protected"
	echo "Blocklist changes will not be compared as this is the first creation of the list"
	date
	} >> /config/scripts/blocklist-processing.txt
	process_blocklist
	echo "First time creation of blocklist complete"
else
	echo "Routine processing of blocklist started"
	{
	echo "Routine processing of blocklist started"
	date
	} >> /config/scripts/blocklist-processing.txt
	process_blocklist
	echo "Routine processing of blocklist complete"
fi
