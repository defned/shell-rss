#!/bin/bash

rdom () { local IFS=\> ; read -d \< E C ;}
usage() {
   echo ""
   echo "Usage: $(basename $0) <-f|--feed> <-o|--output> [-c|--cookie] [-d|--debug] [-p|--period]";
   echo ""
   echo -e "\t-c|--cookie \t\t Cookie(s)i '<key>=<value>;...'"
   echo -e "\t-f|--feed \t\t RSS feed url"
   echo -e "\t-p|--period \t\t Time preiod for RSS feed check"
   echo -e "\t-o|--output \t\t Output directory, where the torrent files will be stored"
   echo -e "\t-d|--debug \t\t Debug level [1..3]"
   echo ""
   exit 1;
}

########################### Get args #############################

period=10

while [[ $# -gt 1 ]]; do
   case "$1" in
      -h|--help)
         usage
         ;;
      -d|--debug)
         debug="$2"
         shift
         ;;
      -p|--period)
         period="$2"
         shift
         ;;
      -f|--feed)
         rssFeed="$2"
         shift
         ;;
      -o|--output)
         downloadDirectory="$2"
         shift
         ;;
      -c|--cookie)
         cookie="$2"
         shift
         ;;
      *)
         usage
         ;;
   esac
   shift
done

############################ Checks ################################

#nick="defnedd"
#pass="338b46ad1427bc818ca5ee41c15213a9"
#rssFeed="https://ncore.cc/bookmarks/ba6cc5b35b3727708bf69334a088ff7a84696"
#cookie="nick=$nick; pass=$pass;"

[[ ! $downloadDirectory ]] && echo "Error: Download directory is empty" && usage;
[[ ! $rssFeed ]] && echo "Error: RSS feed is empty" && usage;

if [ ! -w $downloadDirectory ];then
   echo "Error: Download ($downloadDirectory) directory must exist and be writable"
   usage;
   exit 1;
fi

############################# Core #################################

inItem=0
title=""
pubDate=""
link=""
last=$(date +"%s")

while [[ 1 ]]; do
   echo "[$(date -Iseconds)] Checking RSS feed ... ($rssFeed)";

   [[ $debug -ge 1 ]] && echo "[$(date -Iseconds)] =================================== ($rssFeed) ===========================================" 

   while rdom; do
      [[ $debug == 3 ]] && echo "$E=>$C"

      if [[ $E = item ]]; then if [[ $inItem = 1 ]]; then echo "Error: Malformed RSS"; exit 1; fi; inItem=1; fi;

      if [[ $inItem = 1 ]]; then
         if [[ $E = title ]]; then title="$C";  fi;
         if [[ $E = pubDate ]]; then pubDate=$(date --date="$C" +"%s"); fi;
         if [[ $E = link ]]; then link="$C"; fi;
      fi;
   
      if [[ $E = /item ]]; then
         if [[ $inItem = 0 ]]; then
            echo "Error: Malformed RSS"; exit 1;
         fi;
   
         [[ $debug -ge 1 ]] && echo "[$(date -Iseconds)] [$pubDate] $title ($link)" 

         if [ ${last} -lt ${pubDate} ]; then
            echo "NEW ITEM - [$pubDate] $title ($link)"
            echo "Downloading torrent file via $link ..."
            fileName=$(echo $title | tr " " "_" | sed "s,\([^ ]*\).*,\1.torrent,")
            wget --no-cookies --header "Cookie: $cookie" $link -O "${downloadDirectory}/${fileName}"
            last=$pubDate
         fi
   
         inItem=0;
         title=""
         pubDate=""
         link=""
      fi;

   done < <(curl -s --max-time 60 --cookie "$cookie" --url $rssFeed)
   
   sleep $period;
done
