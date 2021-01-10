#! /bin/bash

_find_friends_followers() {
	echo "Phase I: Start Downloading Targets Friends&Followers ID List"
	cat targets.list | while read _LINE;
	do
		_FRIENDSCOUNT=`twurl /1.1/users/show.json?screen_name=$_LINE | jq .friends_count`
		_FOLLOWERSCOUNT=`twurl /1.1/users/show.json?screen_name=$_LINE | jq .followers_count`
		
		if [ "$_FOLLOWERSCOUNT" -gt 5000 ]; then
			_CURSOR=-1
			until [ "$_CURSOR" -eq 0 ];
			do
				_TWROBOTARRAY=($(twurl accounts | sed  -n '/^[0-9a-zA-Z]/p'))
				_RANDOM_LINE=`shuf -i 0-$((${#_TWROBOTARRAY[@]}-1)) -n 1`
				_TWROBOT=${_TWROBOTARRAY[$_RANDOM_LINE]}
				twurl set default $_TWROBOT
				_REMAINING=`twurl /1.1/application/rate_limit_status.json | jq '.resources.followers."/followers/ids".remaining'`
				echo $_REMAINING
				for (( i=1 ; i<"$_REMAINING" ; i++ ));
				do
					twurl "/1.1/followers/ids.json?cursor=$_CURSOR&screen_name=$_LINE&count=5000" | json-query > ids.tmp
					_CURSOR=`cat ids.tmp | jq .next_cursor`
					echo $_CURSOR
					cat ids.tmp | json-query ids >> $_DATAPATH"/"$_LINE"_followers_ids.txt"
					if [ "$_CURSOR" -eq 0 ];then 
						i=$_REMAINING;
					fi
					_SLEEPTIME=`shuf -i $_MIN-$_MAX -n 1`
					sleep $_SLEEPTIME;
				done;
			done;
		else
			twurl /1.1/followers/ids.json?screen_name=$_LINE | json-query ids > $_DATAPATH"/"$_LINE"_followers_ids.txt";
		fi

		if [ "$_FRIENDSCOUNT" -gt 5000 ]; then
			_CURSOR=-1
			until [ "$_CURSOR" -eq 0 ];
			do
				_TWROBOTARRAY=($(twurl accounts | sed  -n '/^[0-9a-zA-Z]/p'))
				_RANDOM_LINE=`shuf -i 0-$((${#_TWROBOTARRAY[@]}-1)) -n 1`
				_TWROBOT=${_TWROBOTARRAY[$_RANDOM_LINE]}
				twurl set default $_TWROBOT
				_REMAINING=`twurl /1.1/application/rate_limit_status.json | jq '.resources.friends."/friends/ids".remaining'`
				echo $_REMAINING
				for (( i=1 ; i<"$_REMAINING" ; i++ ));
				do
					twurl "/1.1/friends/ids.json?cursor=$_CURSOR&screen_name=$_LINE&count=5000" | json-query > ids.tmp
					_CURSOR=`cat ids.tmp | jq .next_cursor`
					echo $_CURSOR
					cat ids.tmp | json-query ids >>  $_DATAPATH"/"$_LINE"_friends_ids.txt"
					if [ "$_CURSOR" -eq 0 ];then 
						i=$_REMAINING;
					fi
					_SLEEPTIME=`shuf -i $_MIN-$_MAX -n 1`
					sleep $_SLEEPTIME;
				done;
			done;
		else
				twurl /1.1/friends/ids.json?screen_name=$_LINE | json-query ids > $_DATAPATH"/"$_LINE"_friends_ids.txt";
		fi;
	done
	echo "Download Targets Friends&Followers ID List is Done"
	rm ids.tmp
}

_extract_profile(){
	cat $1 | while read _USERS;
	do
		_ID=$_USERS
		twurl /1.1/users/show.json?id=$_ID | jq . > $_USERS.tmp
		_ERRORS=`cat $_USERS.tmp | jq .errors[].message`
		if [ -z "$_ERRORS" ]; then
			_NAME=`cat $_USERS.tmp | jq .name | sed 's/;/,/g'`
			_SCREENNAME=`cat $_USERS.tmp | jq .screen_name | sed 's/;/,/g'`
			_CREATEDAT=`cat $_USERS.tmp | jq .created_at`
			_STATUSESCOUNT=`cat $_USERS.tmp | jq .statuses_count`
			_FRIENDSCOUNT=`cat $_USERS.tmp | jq .friends_count`
			_FOLLOWERSCOUNT=`cat $_USERS.tmp | jq .followers_count`
			_FAVOURITESCOUNT=`cat $_USERS.tmp | jq .favourites_count`
			_LANG=`cat $_USERS.tmp | jq .lang`
			_LOCATION=`cat $_USERS.tmp | jq .location | sed 's/;/,/g'`
			echo $_ID";"$_NAME";"$_SCREENNAME";"$_CREATEDAT";"$_STATUSESCOUNT";"$_FRIENDSCOUNT";"$_FOLLOWERSCOUNT";"$_FAVOURITESCOUNT";"$_LANG";"$_LOCATION >> $2
			sleep 1;
		else
			echo $_ID";;"$_ERRORS >> $2
			sleep 1;
		fi
		rm $_USERS.tmp;
	done
}

_fix_data(){
	_DATE=`date +%Y%m%d%H%M`
	if [ ! -d $_DATE ] ; then
		mkdir $_DATE ;
	fi
	cp "$_DATAPATH/"*"_ids.txt" "./"$_DATE
	> total_followers_friends_ids.tmp
	cat targets.list | while read _LINE;
	do
		cat $_DATAPATH"/"$_LINE"_followers_ids.txt" >> total_followers_friends_ids.tmp
		cat $_DATAPATH"/"$_LINE"_friends_ids.txt" >> total_followers_friends_ids.tmp;
	done
	cat total_followers_friends_ids.tmp | sort -u > total_followers_friends_ids.txt
	awk -F';' '{if(($3 !~ "\"Rate limit exceeded\"")&&($3 != "")) {print $0}}' total_followers_friends_summary.txt | awk -F';' '!array[$1]++' > not_empty_summary.tmp
	cat not_empty_summary.tmp | awk -F';' '{print $1}' | sort > not_empty_ids.tmp
	comm -23 total_followers_friends_ids.txt not_empty_ids.tmp > need_download_ids.txt
	_COUNT=`cat need_download_ids.txt | wc -l`
	cat not_empty_summary.tmp > total_followers_friends_summary.txt
	rm *.tmp
	printf '\033c'
	echo "NEED DOWNLOAD: " $_COUNT
	sleep 3
}



_friends_and_followers_information(){
	echo "Phase II: Start Downloading Targets Friends&Followers Profile"
	_fix_data
	_COUNT=`cat need_download_ids.txt | wc -l`
	_AVERAGE=`expr $_COUNT / $_MULTIPROCESS`
	while [ $_COUNT -gt 0 ];
	do
		for (( i=0;i<$_MULTIPROCESS;i++ ));
		do
			_STARTLINE=`expr $_AVERAGE \* $i + 1`
			_ENDLINE=`echo "$(( $_AVERAGE * ( $i + 1 ) ))"`
			if [ $i -eq $_MULTIPROCESS ]; then
				_ENDLINE=$_COUNT;
			fi
			awk 'NR >= '$_STARTLINE' && NR <= '$_ENDLINE'' need_download_ids.txt > "users_part"$(($i + 1)).tmp
			_ROBOT=`twurl accounts | sed  -n '/^[0-9a-zA-Z]/p' | sed -n "$(($i + 1))"p`
			twurl set default $_ROBOT
			_extract_profile "users_part"$(($i + 1)).tmp  "summary_"$(($i + 1)).tmp &
			echo $!;
		done
		wait
		cat "summary_"*".tmp" >> total_followers_friends_summary.txt
		_fix_data
		_COUNT=`cat need_download_ids.txt | wc -l`;
	done
	
	cat targets.list | while read _LINE;
	do
		> $_DATAPATH"/"$_LINE"_followers_summary.txt"
		awk -F';' 'NR==FNR{c[$1]++;next};c[$1] == 1' $_DATAPATH"/"$_LINE"_followers_ids.txt" total_followers_friends_summary.txt > $_DATAPATH"/"$_LINE"_followers_summary.txt"
		> $_DATAPATH"/"$_LINE"_friends_summary.txt"
		awk -F';' 'NR==FNR{c[$1]++;next};c[$1] == 1' $_DATAPATH"/"$_LINE"_friends_ids.txt" total_followers_friends_summary.txt > $_DATAPATH"/"$_LINE"_friends_summary.txt";
	done
	echo "Download Targets Friends&Followers Profile is Done"
	rm *.tmp
}

_friends_and_followers_pie_chart(){
	cat targets.list | while read _LINE
	do
		if [ -a $_DATAPATH"/"$_LINE"_friends_summary.txt" ]; then
			if [ -a $_DATAPATH"/"$_LINE"_followers_summary.txt" ]; then
				_TOTALFRIENDS=`cat $_DATAPATH"/"$_LINE"_friends_summary.txt" | wc -l`
				echo "TOTALFRIENDS=" $_TOTALFRIENDS
				_TWEET_LESSTHAN_10=`awk 'BEGIN {FS=";"} { if ($5 < 10) { print $0 } }' $_DATAPATH"/"$_LINE"_friends_summary.txt" | wc -l`
				_TWEET_10_TO_50=`awk 'BEGIN {FS=";"} { if ( ($5 >= 10) && ($5 < 50)) { print $0 } }' $_DATAPATH"/"$_LINE"_friends_summary.txt" | wc -l`
				_TWEET_50_TO_100=`awk 'BEGIN {FS=";"} { if ( ($5 >= 50) && ($5 < 100)) { print $0 } }' $_DATAPATH"/"$_LINE"_friends_summary.txt" | wc -l`
				_TWEET_100_TO_200=`awk 'BEGIN {FS=";"} { if ( ($5 >= 100) && ($5 < 200)) { print $0 } }' $_DATAPATH"/"$_LINE"_friends_summary.txt" | wc -l`
				_TWEET_200_TO_500=`awk 'BEGIN {FS=";"} { if ( ($5 >= 200) && ($5 < 500)) { print $0 } }' $_DATAPATH"/"$_LINE"_friends_summary.txt" | wc -l`
				_TWEET_500_TO_1000=`awk 'BEGIN {FS=";"} { if ( ($5 >= 500) && ($5 < 1000)) { print $0 } }' $_DATAPATH"/"$_LINE"_friends_summary.txt" | wc -l`
				_TWEET_MORETHAN_1000=`awk 'BEGIN {FS=";"} { if ( $5 >= 1000 ) { print $0 } }' $_DATAPATH"/"$_LINE"_friends_summary.txt" | wc -l`

				echo "['LESSTHAN 10'," $_TWEET_LESSTHAN_10 "]," >> $_LINE"_friends_tweets_distribution.data"
				echo "['10 to 50'," $_TWEET_10_TO_50 "]," >> $_LINE"_friends_tweets_distribution.data"
				echo "['50 to 100'," $_TWEET_50_TO_100 "]," >> $_LINE"_friends_tweets_distribution.data"
				echo "['100 to 200'," $_TWEET_100_TO_200 "]," >> $_LINE"_friends_tweets_distribution.data"
				echo "['200 to 500'," $_TWEET_200_TO_500 "]," >> $_LINE"_friends_tweets_distribution.data"
				echo "['500 to 1000'," $_TWEET_500_TO_1000 "]," >> $_LINE"_friends_tweets_distribution.data"
				echo "['MORETHAN 1000'," $_TWEET_MORETHAN_1000 "]," >> $_LINE"_friends_tweets_distribution.data"
				cp $_REPORTPATH"/pie.html.templet" $_LINE"_friends_pie.html"
				echo "title: '" $_LINE "关注的人发推情况分布图'" | sed -i '15r /dev/stdin' $_LINE"_friends_pie.html"
				cat $_LINE"_friends_tweets_distribution.data" | sed -i '12r /dev/stdin' $_LINE"_friends_pie.html"

				_TOTALFOLLOWERS=`cat $_DATAPATH"/"$_LINE"_followers_summary.txt" | wc -l`
				echo "TOTALFOLLOWERS=" $_TOTALFOLLOWERS
				_TWEET_LESSTHAN_10=`awk 'BEGIN {FS=";"} { if ($5 < 10) { print $0 } }' $_DATAPATH"/"$_LINE"_followers_summary.txt" | wc -l`
				_TWEET_10_TO_50=`awk 'BEGIN {FS=";"} { if ( ($5 >= 10) && ($5 < 50)) { print $0 } }' $_DATAPATH"/"$_LINE"_followers_summary.txt" | wc -l`
				_TWEET_50_TO_100=`awk 'BEGIN {FS=";"} { if ( ($5 >= 50) && ($5 < 100)) { print $0 } }' $_DATAPATH"/"$_LINE"_followers_summary.txt" | wc -l`
				_TWEET_100_TO_200=`awk 'BEGIN {FS=";"} { if ( ($5 >= 100) && ($5 < 200)) { print $0 } }' $_DATAPATH"/"$_LINE"_followers_summary.txt" | wc -l`
				_TWEET_200_TO_500=`awk 'BEGIN {FS=";"} { if ( ($5 >= 200) && ($5 < 500)) { print $0 } }' $_DATAPATH"/"$_LINE"_followers_summary.txt" | wc -l`
				_TWEET_500_TO_1000=`awk 'BEGIN {FS=";"} { if ( ($5 >= 500) && ($5 < 1000)) { print $0 } }' $_DATAPATH"/"$_LINE"_followers_summary.txt" | wc -l`
				_TWEET_MORETHAN_1000=`awk 'BEGIN {FS=";"} { if ( $5 >= 1000 ) { print $0 } }' $_DATAPATH"/"$_LINE"_followers_summary.txt" | wc -l`

				echo "['LESSTHAN 10'," $_TWEET_LESSTHAN_10 "]," >> $_LINE"_followers_tweets_distribution.data"
				echo "['10 to 50'," $_TWEET_10_TO_50 "]," >> $_LINE"_followers_tweets_distribution.data"
				echo "['50 to 100'," $_TWEET_50_TO_100 "]," >> $_LINE"_followers_tweets_distribution.data"
				echo "['100 to 200'," $_TWEET_100_TO_200 "]," >> $_LINE"_followers_tweets_distribution.data"
				echo "['200 to 500'," $_TWEET_200_TO_500 "]," >> $_LINE"_followers_tweets_distribution.data"
				echo "['500 to 1000'," $_TWEET_500_TO_1000 "]," >> $_LINE"_followers_tweets_distribution.data"
				echo "['MORETHAN 1000'," $_TWEET_MORETHAN_1000 "]," >> $_LINE"_followers_tweets_distribution.data"
				cp $_REPORTPATH"/pie.html.templet" $_LINE"_followers_pie.html"
				echo "title: '关注" $_LINE "的人发推情况分布图'" | sed -i '15r /dev/stdin' $_LINE"_followers_pie.html"
				cat $_LINE"_followers_tweets_distribution.data" | sed -i '12r /dev/stdin' $_LINE"_followers_pie.html";
			fi;
		fi;
	done
	rm  *.data
	mv  *.html $_REPORTPATH
}

_friends_and_followers_bar_chart(){
	cat targets.list | while read _LINE
	do
	cat $_DATAPATH"/"$_LINE"_followers_summary.txt" | awk -F";" '{print $4}' | sed '/^$/d'| sed 's/"//g' |awk '{ print $6, $2 }' | sort | uniq -c | sort -k2,2 -k3M > data.tmp
	cat $_DATAPATH"/"$_LINE"_followers_summary.txt" | awk -F";" '{print $4}' | sed '/^$/d'| sed 's/"//g' |awk '{ print $6 }' | sort -u > year.tmp

	cat year.tmp | while read _YEAR;
	do 
		_MATRIX=`grep $_YEAR" Jan" data.tmp`
		if [ -z "$_MATRIX" ]; then
			echo -n "['"$_YEAR"', 0" >> $_LINE"_followers_registerbydate.tmp";
		else
			_NUM=`echo $_MATRIX | awk '{print $1}'`
			echo -n "['"$_YEAR"', "$_NUM >> $_LINE"_followers_registerbydate.tmp";
		fi
	
		_MATRIX=`grep $_YEAR" Feb" data.tmp`
		if [ -z "$_MATRIX" ]; then
			echo -n ", 0" >> $_LINE"_followers_registerbydate.tmp";
		else
			_NUM=`echo $_MATRIX | awk '{print $1}'`
			echo -n ", "$_NUM >> $_LINE"_followers_registerbydate.tmp";
		fi
	
		_MATRIX=`grep $_YEAR" Mar" data.tmp`
		if [ -z "$_MATRIX" ]; then
			echo -n ", 0" >> $_LINE"_followers_registerbydate.tmp";
		else
			_NUM=`echo $_MATRIX | awk '{print $1}'`
			echo -n ", "$_NUM >> $_LINE"_followers_registerbydate.tmp";
		fi
	
		_MATRIX=`grep $_YEAR" Apr" data.tmp`
		if [ -z "$_MATRIX" ]; then
			echo -n ", 0" >> $_LINE"_followers_registerbydate.tmp";
		else
			_NUM=`echo $_MATRIX | awk '{print $1}'`
			echo -n ", "$_NUM >> $_LINE"_followers_registerbydate.tmp";
		fi
	
		_MATRIX=`grep $_YEAR" May" data.tmp`
		if [ -z "$_MATRIX" ]; then
			echo -n ", 0" >> $_LINE"_followers_registerbydate.tmp";
		else
			_NUM=`echo $_MATRIX | awk '{print $1}'`
			echo -n ", "$_NUM >> $_LINE"_followers_registerbydate.tmp";
		fi
	
		_MATRIX=`grep $_YEAR" Jun" data.tmp`
		if [ -z "$_MATRIX" ]; then
			echo -n ", 0" >> $_LINE"_followers_registerbydate.tmp";
		else
			_NUM=`echo $_MATRIX | awk '{print $1}'`
			echo -n ", "$_NUM >> $_LINE"_followers_registerbydate.tmp";
		fi
	
		_MATRIX=`grep $_YEAR" Jul" data.tmp`
		if [ -z "$_MATRIX" ]; then
			echo -n ", 0" >> $_LINE"_followers_registerbydate.tmp";
		else
			_NUM=`echo $_MATRIX | awk '{print $1}'`
			echo -n ", "$_NUM >> $_LINE"_followers_registerbydate.tmp";
		fi
	
		_MATRIX=`grep $_YEAR" Aug" data.tmp`
		if [ -z "$_MATRIX" ]; then
			echo -n ", 0" >> $_LINE"_followers_registerbydate.tmp";
		else
			_NUM=`echo $_MATRIX | awk '{print $1}'`
			echo -n ", "$_NUM >> $_LINE"_followers_registerbydate.tmp";
		fi
	
		_MATRIX=`grep $_YEAR" Sep" data.tmp`
		if [ -z "$_MATRIX" ]; then
			echo -n ", 0" >> $_LINE"_followers_registerbydate.tmp";
		else
			_NUM=`echo $_MATRIX | awk '{print $1}'`
			echo -n ", "$_NUM >> $_LINE"_followers_registerbydate.tmp";
		fi
	
		_MATRIX=`grep $_YEAR" Oct" data.tmp`
		if [ -z "$_MATRIX" ]; then
			echo -n ", 0" >> $_LINE"_followers_registerbydate.tmp";
		else
			_NUM=`echo $_MATRIX | awk '{print $1}'`
			echo -n ", "$_NUM >> $_LINE"_followers_registerbydate.tmp";
		fi
	
		_MATRIX=`grep $_YEAR" Nov" data.tmp`
		if [ -z "$_MATRIX" ]; then
			echo -n ", 0" >> $_LINE"_followers_registerbydate.tmp";
		else
			_NUM=`echo $_MATRIX | awk '{print $1}'`
			echo -n ", "$_NUM >> $_LINE"_followers_registerbydate.tmp";
		fi
	
		_MATRIX=`grep $_YEAR" Dec" data.tmp`
		if [ -z "$_MATRIX" ]; then
			echo  ", 0]," >> $_LINE"_followers_registerbydate.tmp";
		else
			_NUM=`echo $_MATRIX | awk '{print $1}'`
			echo ", "$_NUM"]," >> $_LINE"_followers_registerbydate.tmp";
		fi;
	done
	cp $_REPORTPATH"/bar.html.templet" $_LINE"_followers_registerbydate_bar.html"
	echo "title: '"$_LINE"粉丝注册时间分布图'," | sed -i '15r /dev/stdin' $_LINE"_followers_registerbydate_bar.html"
	cat $_LINE"_followers_registerbydate.tmp" | sed -i '11r /dev/stdin' $_LINE"_followers_registerbydate_bar.html";
	done
	rm *.tmp
	mv *.html $_REPORTPATH
}


_who_blocked_me(){
	_MASTERUSER=anonymous_adm
	twurl set default $_MASTERUSER
	cat total_followers_friends_summary.txt | while read _LINE;
	do
		_SCREENNAME=`echo $_LINE | awk -F";" '{print $3}'`
		_ERRORCODE=`twurl /1.1/statuses/user_timeline.json?screen_name=$_SCREENNAME | jq .errors[].code`
		if [ "$_ERRORCODE" = 136 ]; then
			echo $_LINE\n >> blockedme.list
			sleep 1;
		fi
		if [ "$_ERRORCODE" = 88 ]; then
			sleep 900;
		fi
		sleep 1;
	done
}

function ctrl_c() {
	clear
	sleep 2
	clear
	echo "Write records back into file, please wait......"
	cat "summary_"*".tmp" >> total_followers_friends_summary.txt
	_fix_data
	exit
}

#####  MAIN  #####
###########################################################
. init.conf
while : ;
do
	clear
	trap ctrl_c SIGINT
	echo  "###################################################"
	echo  "# 1) Download Targets Friends&Followers ID List   #"
	echo  "#                                                 #"
	echo  "# 2) Download Targets Friends&Followers Profile   #"
	echo  "#                                                 #"
	echo  "# 3) View Download Friends&Followers Number       #"
	echo  "#                                                 #"
	echo  "# 4) Analyse Targets Friends&Followers            #"
	echo  "#                                                 #"
	echo  "# 5) Who Blocked ME                               #"
	echo  "#                                                 #"
	echo  "# Quit(Q|q)                                       #"
	echo  "###################################################"
	echo
	echo -n "Please enter your choice: "
	read _OPT
	case $_OPT in
			1)
				_find_friends_followers
				;;

			2)
				_friends_and_followers_information
				;;

			3)
				_fix_data
				;;
			
			4)
				_friends_and_followers_pie_chart
				_friends_and_followers_bar_chart
				;;

			5)
				_who_blocked_me
				;;

			Q|q)
				break
				;;
			
			*)
				echo "invalid option please choose again"
				;;
	esac;
done

