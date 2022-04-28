# Time-stamp: <Thu 2022-04-28 09:25 jmorey>
################################################################################
# [/etc/]profile.d/slurm.sh - Various Slurm helper functions and aliases to
# .                           use on the UL HPC Platform (https://hpc.uni.lu)
#
# Copyright (c) 2020 UL HPC Team <hpc-team@uni.lu>
#
# Usage:       source path/to/slurm.sh
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
################################################################################


################################################################################
#   AZURE INSTRUCTIONS
#       1. copy script (ie. sbill.sh) to login and/or scheduler node(s)
#       2. Modify the "partition" array with your specific Partition names & costs
#       3. Copy script to /etc/profile.d/sbill.sh
#       4. source /etc/profile.d/sbill.sh
#       5. Run the function as sbill [...]
#
#   NOTE:
#       - This script assumes 1 job per compute node
################################################################################


# Default formats
#export SQUEUE_FORMAT="%.8i %.6P %.9q %.20j %.10u %.4D %.5C %.2t %.12M %.12L %.8Q %R"

### Most useful format field for squeue (see man squeue)
#   --format      --Format
# | Short (-o) | Long (-O)    | Description                                        |
# |------------|--------------|----------------------------------------------------|
# | %i         | JobID        | Job ID                                             |
# | %j         | Name         | Job or job step name.                              |
# | %R         | ReasonList   | For pending jobs: the reason a job is waiting      |
# | %t         | StateCompact | Job state in compact form.                         |
# | %P         | Partition    | Partition                                          |
# | %q         | QOS          | Quality of service associated with the job.        |
# | %u         | UserID       | User name for a job or job step.                   |
# | %D         | NumNodes     | Number of nodes allocated to the job               |
# | %C         | NumCPUs      | Number of CPUs (cores)                             |
# | %A         | NumTasks     | Number of tasks                                    |
# |            | NTPerNode    | The number of task per node                        |
# | %l         | TimeLimit    | Time limit of the job: days-hours:minutes:seconds  |
# | %M         | TimeUsed     | Time used by the job:  days-hours:minutes:seconds  |
# | %L         | TimeLeft     | Time left for the job: days-hours:minutes:seconds. |


###
# Job billing utility
##
sbill() {
    local start=$(date +%F)
    local end=$(date +"%Y-%m-%dT%H:%M")
    # in the array add the [partion_name]=cost
    declare -A partition=( [execute]=3.04 [midmem]=2.02 [lowmem]=0.085 )
    local jobid=""
    local options=""
    local username=""
    while [ -n "$1" ]; do
        case $1 in
            -S | --start) shift; start=$1;;
            -E | --end)   shift; end=$1;;
            -m | -M | --month) start="$(date +%Y-%m)-01";;
            -y | -Y | --year)  start="$(date +%Y)-01-01";;
	        -u | --user) shift; username=$1;;
            -j | --jobid)  shift; jobid=$1;;
            -h | --help)
	        echo "Display job charging / billing summary";
		    echo " ";
		    echo "Usage: ";
            echo "       sbill -j <jobid>        # Show a specific job cost";
		    echo " ";
            echo "       sbill [-m] [-Y] [-S YYYY-MM-DD] [-E YYYT-MM-DDTHH:MM]    # Show costs for all jobs for all user";
		    echo "		-m = From start of the current Month";
		    echo "		-Y = From start of the current Year";
		    echo "		-S = Specific START Date; DEFAULT=Today";
		    echo "		-E = Specific END Date; DEFAULT=Now";
		    echo " ";
            echo "       sbill -u <username> [...]     # Show costs for all jobs for a specific user";
            echo " ";
        return;;
#        *) options=$*; break;;
        *) jobid=$*; break;;
        esac
        shift
    done
    if [ -n "${jobid}" ]; then
        cmd="sacct -X --format=JobName,AllocTRES%60,ElapsedRaw -j ${jobid}"
        echo "# ${cmd}"
        $cmd
        echo " "
        test=$($cmd -n -P | cut -d "|" -f1 )
        if [ -n "${test}" ]; then
            local nodes=$($cmd -n -P | cut -d '|' -f 2 | tr ',' '\n' | grep node | cut -d '=' -f 2)
            local part=$(sacct -X -j ${jobid} -P | grep ${jobid} | cut -d "|" -f 3)
            local sec=$(sacct -X --format=ElapsedRaw -j ${jobid} -n -P)
            local usage=$(printf "%0.2f\n" $(echo "$nodes*$sec/3600" | bc -l))
            local cost=$(printf "$%0.2f\n" $(echo "$usage*${partition[$part]}" | bc -l))
            echo "		Total usage:	$usage VMU (Estimated price:	$cost)"
        else
            echo "JobID ${jobid} does not exist"
        fi
    elif [ -n "${username}" ]; then
        cmd="sacct -X --format=jobid,user,partition,AllocNodes%10,ElapsedRaw -u ${username} --starttime ${start} --endtime ${end}"
        echo "# ${cmd}"
        $cmd
        echo " "
        test=$($cmd -n -P | cut -d "|" -f1 )
        if [ -n "${test}" ]; then
            for i in ${!partition[@]}; do
                local walltime=$($cmd -n -P | grep $i | awk -F '|' '{sec += $5*$4} END {print sec}')
                if [ -n "${walltime}" ]; then
	                local usage=$(printf "%0.2f\n" $(echo "$walltime/3600" | bc -l))
                    local cost=$(printf "$%0.2f\n" $(echo "$usage*${partition[$i]}" | bc -l)) 
                    echo "	$i usage:	$usage VMU ($i estimated  price:	$cost)"
                else
                    echo "	$i usage:	0.00 VMU ($i estimated  price:	\$0.00)"
                    continue
                fi
            done
        else
            echo "No jobs during this timeframe:  ${start} - ${end}"
        fi
    else
        cmd="sacct -X --format=jobid,user,partition,AllocNodes%10,ElapsedRaw -a --starttime ${start} --endtime ${end}"
        echo "# ${cmd}"
        $cmd
        echo " "
        test=$($cmd -n -P | cut -d "|" -f1 )
        if [ -n "${test}" ]; then
      	    for i in ${!partition[@]}; do
                local walltime=$($cmd -n -P | grep $i | awk -F '|' '{sec += $5*$4} END {print sec}')
                if [ -n "${walltime}" ]; then
                    local usage=$(printf "%0.2f\n" $(echo "$walltime/3600" | bc -l))
                    local cost=$(printf "$%0.2f\n" $(echo "$usage*${partition[$i]}" | bc -l))
                    echo "	$i usage:	$usage VMU ($i estimated  price:	$cost)"
                else 
                    echo "	$i usage:	0.00 VMU ($i estimated  price:	\$0.00)"
                    continue
                fi
      	    done
        else 
            echo "No jobs during this timeframe:  ${start} - ${end}"
        fi
    fi
}