#!/bin/bash
#
# Author        :Julio Sanz
# Website       :www.elarraydejota.com
# Email         :juliojosesb@gmail.com
# Description   :Script to check SSL certificate expiration date of a list of sites. Recommended to use with a dark terminal theme to
#                see the colors correctly. The terminal also needs to support 256 colors.
# Dependencies  :openssl, mutt (if you use the mail option)
# License       :GPLv3
#

#
# VARIABLES
#

sites_list="$1"
html_file="certs_check.html"

sitename=""
current_date=$(date +%s)
end_date=""
days_left=""
certificate_last_day=""

warning_days="30"
alert_days="15"

# Terminal colors
ok_color="\e[38;5;40m"
warning_color="\e[38;5;220m"
alert_color="\e[38;5;208m"
expired_color="\e[38;5;196m"
end_of_color="\033[0m"

#
# FUNCTIONS
#

calculate()
{
	sitename=$(echo $1 | cut -d ":" -f1)
	
	certificate_last_day=$(date -d "$(echo | openssl s_client -connect ${sitename}:443 2>/dev/null | openssl x509 -noout -dates|grep notAfter|cut -d= -f2)" +%Y-%m-%d)

	end_date=$(date +%s -d "$certificate_last_day")

	days_left=$(((end_date - current_date) / 86400))
}

html_mode()
{
	# Generate and reset file
	cat <<- EOF > $html_file
	<!DOCTYPE html>
	<html>
			<head>
			<title>SSL Certs Expiration Report</title>
			<style>
				body {
					background-color: white;
					font-family: 'Arial', sans-serif;
				}
				h1 {
					color: #253858;
					text-align: center;
					font-size: 20px;
					font-weight: bold;
				}
				table {
					background-color: #efefef;
					padding: 10px;
					font-size: 14px;
					font-family: monospace;
					margin-left: auto;
					margin-right: auto;
					border: 1px solid #ccc;
					border-radius: 6px;
					min-width: 600px;
				}
				tr {
					padding: 8px;
					text-align: left;
				}
				th {
					 color: #253858;
					 padding: 0 30px 8px 0;
					 text-align: left;
					 font-weight: bold;
				}
				td {
					padding: 8px;
				}
				tr.ok > td {
					background-color: #7DC242;
				}
				tr.alert > td {
					background-color: #FF8F32;
				}
				tr.warning > td {
					background-color: #FFE032;
				}
				tr.expired > td {
					background-color: #EB655A;
				}
			</style>
			</head>
			<body>
					<h1>SSL Certs Expiration Report</h1>
					<table>
					<tr>
					<th>Site</th>
					<th>Expiration Date</th>
					<th>Days Left</th>
					<th>Status</th>
					</tr>
	EOF

	while read site;do
		calculate $site

		if [ "$days_left" -gt "$warning_days" ];then
			echo "<tr class=\"ok\">" >> $html_file
			echo "<td>${sitename}</td>" >> $html_file
			echo "<td>${certificate_last_day}</td>" >> $html_file
			echo "<td>${days_left}</td>" >> $html_file
			echo "<td>OK</td>" >> $html_file
			echo "</tr>" >> $html_file

		elif [ "$days_left" -le "$warning_days" ] && [ "$days_left" -gt "$alert_days" ];then
			echo "<tr class=\"warning\">" >> $html_file
			echo "<td>${sitename}</td>" >> $html_file
			echo "<td>${certificate_last_day}</td>" >> $html_file
			echo "<td>${days_left}</td>" >> $html_file
			echo "<td>Warning</td>" >> $html_file
			echo "</tr>" >> $html_file

		elif [ "$days_left" -le "$alert_days" ] && [ "$days_left" -gt 0 ];then
			echo "<tr class=\"alert\">" >> $html_file
			echo "<td>${sitename}</td>" >> $html_file
			echo "<td>${certificate_last_day}</td>" >> $html_file
			echo "<td>${days_left}</td>" >> $html_file
			echo "<td>Alert</td>" >> $html_file
			echo "</tr>" >> $html_file

		elif [ "$days_left" -le 0 ];then
			echo "<tr class=\"expired\">" >> $html_file
			echo "<td>${sitename}</td>" >> $html_file
			echo "<td>${certificate_last_day}</td>" >> $html_file
			echo "<td>${days_left}</td>" >> $html_file
			echo "<td>Expired</td>" >> $html_file
			echo "</tr>" >> $html_file

		fi
	done < ${sites_list}

	# Close main HTML tags
	cat <<- EOF >> $html_file
			</table>
			</body>
	</html>
	EOF
}

terminal_mode()
{
	printf "\n| %-30s | %-30s | %-10s | %-5s %s\n" "SITE" "EXPIRATION DAY" "DAYS LEFT" "STATUS"

	while read site;do

		calculate $site

		if [ "$days_left" -gt "$warning_days" ];then
			printf "${ok_color}| %-30s | %-30s | %-10s | %-5s %s\n${end_of_color}" \
			"$sitename" "$certificate_last_day" "$days_left" "OK"

		elif [ "$days_left" -le "$warning_days" ] && [ "$days_left" -gt "$alert_days" ];then
			printf "${warning_color}| %-30s | %-30s | %-10s | %-5s %s\n${end_of_color}" \
			"$sitename" "$certificate_last_day" "$days_left" "Warning"

		elif [ "$days_left" -le "$alert_days" ] && [ "$days_left" -gt 0 ];then
			printf "${alert_color}| %-30s | %-30s | %-10s | %-5s %s\n${end_of_color}" \
			"$sitename" "$certificate_last_day" "$days_left" "Alert"

		elif [ "$days_left" -le 0 ];then
			printf "${expired_color}| %-30s | %-30s | %-10s | %-5s %s\n${end_of_color}" \
			"$sitename" "$certificate_last_day" "$days_left" "Expired"
		fi

	done < $sites_list

	printf "\n %-10s" "STATUS LEGEND"
	printf "\n ${ok_color}%-8s${end_of_color} %-30s" "OK" "- More than ${warning_days} days left until the certificate expires"
	printf "\n ${warning_color}%-8s${end_of_color} %-30s" "Warning" "- The certificate will expire in less than ${warning_days} days"
	printf "\n ${alert_color}%-8s${end_of_color} %-30s" "Alert" "- The certificate will expire in less than ${alert_days} days"
	printf "\n ${expired_color}%-8s${end_of_color} %-30s\n\n" "Expired" "- The certificate has already expired"
}

howtouse()
{
	cat <<-'EOF'

	You must always specify -f option with the name of the file that contains the list of sites to check
	Options:
		-f [ sitelist file ]          list of sites (domains) to check
		-o [ html | terminal ]        output (can be html or terminal)
		-m [ mail ]                   mail address to send the graphs to
		-h                            help
	
	Examples:

		# Launch the script in terminal mode:
		./jota-cert-checker.sh -f sitelist -o terminal

		# Using HTML mode:
		./jota-cert-checker.sh -f sitelist -o html

		# Using HTML mode and sending results via email
		./jota-cert-checker.sh -f sitelist -o html -m mail@example.com

	EOF
}

# 
# MAIN
# 

if [ "$#" -eq 0 ];then
	howtouse

elif [ "$#" -ne 0 ];then
	while getopts ":f:o:m:h" opt; do
		case $opt in
			"f")
				sites_list="$OPTARG"
				;;
			"o")
				output="$OPTARG"
				if [ "$output" == "terminal" ];then
					terminal_mode
				elif [ "$output" == "html" ];then
					html_mode
				else
					echo "Wrong output selected"
					howtouse
				fi
				;;
			"m")
				if [ "$output" == "html" ];then
					mail_to="$OPTARG"
				else
					echo "Mail option is only used with HTML mode"
				fi
				;;
			\?)
				echo "Invalid option: -$OPTARG" >&2
				howtouse
				exit 1
				;;
			:)
				echo "Option -$OPTARG requires an argument." >&2
				howtouse
				exit 1
				;;
			"h" | *)
				howtouse
				exit 1
				;;
		esac
	done

	# Send mail if specified
	if [[ $mail_to ]];then
		mutt -e 'set content_type="text/html"' $mail_to -s "SSL certs expiration check" < $html_file
	fi
fi
