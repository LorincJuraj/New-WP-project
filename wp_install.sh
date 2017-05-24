#!/bin/bash

# include config file located in the same dir as the wp_install.sh script
source `dirname $0`/wp_install.cfg 2>/dev/null

start=`date +%s`

echo
read -e -i "$wpdir" -p $'\e[32mCreate WordPress directory:\e[0m ' input
wpdir=$input
mkdir -p "$wpdir"

currentdir=${PWD:${#htdocspath}}
dbname=$currentdir
dbname=${dbname//\//_}_${wpdir//\//_}

read -e -i "$dbname" -p $'\e[32mDatabase name:\e[0m ' input
dbname=$input

RESULT=`mysqlshow --user=$dbuser --password=$dbpass $dbname| grep -v Wildcard | grep -v "Warning: Using a password" | grep -o $dbname`

#Check if desired database exists
if [ "$RESULT" == "$dbname" ]; then
  read -e -p $'\e[31mThe database \e[1m`'$dbname$'`\e[21m already exists. Do you want to \e[1md\e[21melete the database and continue or \e[1mq\e[21muit? (\e[1md/q\e[21m): \e[0m' -n 1 -r

  # If the database exists you can either deleted or cancell whole process.
	if [[ $REPLY =~ ^[Dd]$ ]]; then
  	mysql --user="$dbuser" --password="$dbpass" --execute='DROP DATABASE '$dbname';'
  else
  	echo
  	exit
  fi
fi

mysql --user="$dbuser" --password="$dbpass" --execute='CREATE DATABASE '$dbname';'

# Basic WordPress configuration
url=$url$currentdir/$wpdir
read -e -i "$url" -p $'\e[32mWP url:\e[0m ' input
url=$input

read -e -i "$wptitle" -p $'\e[32mWP title:\e[0m ' input
wptitle=$input

read -e -i "$wpadmin" -p $'\e[32mWP admin:\e[0m ' input
wpadmin=$input

read -e -i "$wppass" -p $'\e[32mWP pass:\e[0m ' input
wppass=$input

read -e -i "$wpmail" -p $'\e[32mWP mail:\e[0m ' input
wpmail=$input

read -e -i "$wprewrite" -p $'\e[32mWP rewrite structure:\e[0m ' input
wprewrite=$input

# WordPress installation
cd $wpdir
echo $'\e[32mDownloading WordPress\e[0m'
wp core download
wp core config --dbname=$dbname --dbuser=$dbuser --dbpass=$dbpass
wp core install --url=$url --title="$wptitle" --admin_user="$wpadmin" --admin_password="$wppass" --admin_email="$wpmail"
echo $'\e[32mWordPress installed\e[0m'
wp rewrite structure \"$wprewrite\"

projectpath=$htdocspath$currentdir/$wpdir

# Scaffolding blnk theme
read -e -p $'\e[32mDo you want to scaffold theme? ( \e[1mY/N\e[21m ) \e[0m' -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then

	[[ -z "${themename// }" ]] && themename=$wptitle
	read -e -i "$themename" -p $'\e[32mTheme name:\e[0m ' input
	themename=$input

	themeslug=${themename// /-}
	themeslug=${themeslug,,}
	read -e -i "$themeslug" -p $'\e[32mTheme slug:\e[0m ' input
	themeslug=$input

	read -e -i "$themeauthor" -p $'\e[32mTheme author:\e[0m ' input
	themeauthor=$input

	read -e -i "$themeauthoruri" -p $'\e[32mTheme author uri:\e[0m ' input
	themeauthoruri=$input

	wp scaffold _s "$themeslug" --theme_name="$themename" --author="$themeauthor" --author_uri="$themeauthoruri" --activate

	sublimeprojecttheme=$(cat <<EOF
				{
			    "name": "THEMES",
			    "path": "$projectpath/wp-content/themes"
		    },
EOF
)
else
	sublimeprojecttheme=$(cat <<EOF
			/*{
			    "name": "THEMES",
			    "path": "$projectpath/wp-content/themes"
		    },*/
EOF
)
fi

# Deleting unneeded themes
read -e -p $'\e[32mDo you want delete unneeded themes (2015 & 2016)? ( \e[1mY/N\e[21m ) \e[0m' -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
	wp theme delete twentyfifteen
	wp theme delete twentysixteen
fi

# Scaffolding blank plugin
read -e -p $'\e[32mDo you want to scaffold plugin? ( \e[1mY/N\e[21m ) \e[0m' -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then

	[[ -z "${pluginname// }" ]] && pluginname=$wptitle
	read -e -i "$pluginname" -p $'\e[32mPlugin name:\e[0m ' input
	pluginname=$input

	pluginslug=${pluginname// /-}
	pluginslug=${pluginslug,,}
	read -e -i "$pluginslug" -p $'\e[32mPlugin slug:\e[0m ' input
	pluginslug=$input

	read -e -i "$pluginuri" -p $'\e[32mPlugin uri:\e[0m ' input
	pluginuri=$input

	read -e -i "$pluginauthor" -p $'\e[32mPlugin author:\e[0m ' input
	pluginauthor=$input

	read -e -i "$pluginauthoruri" -p $'\e[32mPlugin author uri:\e[0m ' input
	pluginauthoruri=$input

	wp scaffold plugin $pluginslug --plugin_name="$pluginname" --plugin_author="$pluginauthor" --plugin_author_uri="$pluginauthoruri" --plugin_uri="$pluginuri" --skip-tests

	sublimeprojectplugin=$(cat <<EOF
				{
			    "name": "PLUGINS",
			    "path": "$projectpath/wp-content/plugins"
		    },
EOF
)
else
	sublimeprojectplugin=$(cat <<EOF
			/*{
			    "name": "PLUGINS",
			    "path": "$projectpath/wp-content/plugins"
		    },*/
EOF
)
fi

# Creating Toggl.com project (Toggle.com is online timetracker supporting, projects, workspaces etc. in free version)
read -e -p $'\e[32mDo you want to create Toggl project? ( \e[1mY/N\e[21m ) \e[0m' -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then

	read -e -i "$wptitle" -p $'\e[32mToggl project name:\e[0m ' input
	togglprojectname=$input

	curl -v -u $togglapitoken:api_token \
    -H "Content-Type: application/json" \
    -d "{\"project\":{\"name\":\"$togglprojectname\",\"wid\":\"$togglworkspaceid\",\"is_private\":true,\"color\":$togglcolor}}" \
    -X POST https://www.toggl.com/api/v8/projects
  echo
fi

# Creating SublimeText 3 project (should work on ST2 too, but not tested)
read -e -p $'\e[32mDo you want to create SublimeText project? ( \e[1mY/N\e[21m ) \e[0m' -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
	read -e -p $'\e[32mDo you want to create END OF DAY script shortcut? ( \e[1mY/N\e[21m ) \e[0m' -n 1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then

		read -e -i "$projectpath/.project" -p $'\e[32mEnd of day script path:\e[0m ' input
		eodpath=$input
		mkdir -p -- "$eodpath" || exit
		cp -- "$eodsrc" "$eodpath/"
		endofday=$(cat <<EOF
				{
	      	"name": "PROJECT FILES",
	      	"path": "$eodpath"
	    	},
EOF
)
	fi

	# Creating ToDo.md file - it's my To Do list (with some additional stuff) for each project
	read -e -p $'\e[32mDo you want to create ToDO.md file? ( \e[1mY/N\e[21m ) \e[0m' -n 1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
			echo "$todocontent" > "$eodpath/ToDo.md"
	fi

	read -e -i "$wptitle" -p $'\e[32mSublime project title:\e[0m ' input
	subltitle=$input

	sublimeprojectdata=$(cat <<EOF
		{
		  "folders":
		  [
$sublimeprojecttheme
$sublimeprojectplugin
$endofday
		  ]
		}
EOF
)

	echo "$sublimeprojectdata" > "$sublprojectpath/$subltitle.sublime-project"
	read -e -p $'\e[32mDo you want to start the SublimeText project now? ( \e[1mY/N\e[21m ) \e[0m' -n 1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		subl "$sublprojectpath/$subltitle.sublime-project"
	fi
fi

end=`date +%s`
runtime=$((end-start))

# Tadaaaaa :-)
echo
echo $'\e[42m\e[30m                                \e[0m'
echo $'\e[42m\e[30m        You are all set.        \e[0m'
echo $'\e[42m\e[30m                                \e[0m'
echo
echo $'And it all took just \e[32m'$runtime$' seconds\e[0m'
echo

# And here are urls to your WordPress project's front- and backend
echo $url
echo $url'/wp-admin'
echo





# That's all folks !

# https://www.youtube.com/watch?v=gAj8jLe_shQ