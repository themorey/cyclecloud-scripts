#!/bin/bash
#SBATCH --job-name=beeond-test
#SBATCH -N 2
#SBATCH -n 40
#SBATCH -p hpc

## NOTE: /mnt/nvme and /mnt/beeond are created in cloud-init script
## NOTE: Uncomment the following lines if NOT using the Prolog to start Beeond
#echo "$DATE creating Slurm Job $SLURM_JOB_ID nodefile"
#scontrol show hostnames $SLURM_JOB_NODELIST > /shared/home/$SLURM_JOB_USER/nodefile-$SLURM_JOB_ID
#echo "Starting Beeond on $SLURM_JOB_NODELIST"
#beeond start -n /shared/home/$SLURM_JOB_USER/nodefile-$SLURM_JOB_ID -d /mnt/nvme -c /mnt/beeond -P

echo "df -h:   "
df -h
echo ""
echo "beegfs-ctl --mount=/mnt/beeond --listnodes --nodetype=storage:   "
beegfs-ctl --mount=/mnt/beeond --listnodes --nodetype=storage
echo ""
echo "beegfs-ctl --mount=/mnt/beeond --listnodes --nodetype=metadata:   "
beegfs-ctl --mount=/mnt/beeond --listnodes --nodetype=metadata
echo ""
echo "beegfs-ctl --mount=/mnt/beeond --getentryinfo:   "
beegfs-ctl --mount=/mnt/beeond --getentryinfo /mnt/beeond
echo ""
echo "beegfs-net:   "
beegfs-net

## NOTE: Uncomment the following lines if NOT using the Epilog to stop Beeond
# echo "Stopping Beeond filesystem on nodes $SLURM_JOB_NODELIST
#beeond stop -n /shared/home/$SLURM_JOB_USER/nodefile-$SLURM_JOB_ID -L -d -P -c >> $logfile 2>&1
