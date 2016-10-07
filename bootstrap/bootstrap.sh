##
#
set -o errexit -o nounset -o pipefail 

declare -i OVERALL_RC=0
declare PROXY="3.39.86.231"

# Check if this is a terminal, and if colors are supported, set some basic
# colors for outputs
if [ -t 1 ]; then
    colors_supported=$(tput colors)
    if [[ $colors_supported -ge 8 ]]; then
        RED='\e[1;31m'
        BOLD='\e[1m'
        NORMAL='\e[0m'
    fi
fi
# Setup getopt argument parser
ARGS=$(getopt -o dph --long "disable-preflight,preflight-only,help,no-block-dcos-setup" -n "$(basename "$0")" -- "$@")

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

function check_command_exists() {
    COMMAND=$1
    DISPLAY_NAME=${2:-$COMMAND}

    echo -e -n "Checking if $DISPLAY_NAME is installed and in PATH: "
    $( command -v $COMMAND >/dev/null 2>&1 || exit 1 )
    RC=$?
    print_status $RC
    (( OVERALL_RC += $RC ))
    return $RC
}


function check_version() {
    COMMAND_NAME=$1
    VERSION_ATLEAST=$2
    COMMAND_VERSION=$3
    DISPLAY_NAME=${4:-$COMMAND}

    echo -e -n "Checking $DISPLAY_NAME version requirement (>= $VERSION_ATLEAST): "
    version_gt $COMMAND_VERSION $VERSION_ATLEAST
    RC=$?
    print_status $RC "${NORMAL}($COMMAND_VERSION)"
    (( OVERALL_RC += $RC ))
    return $RC
}

# Pre-requsites
function pre_requisite() {
    apt-key adv --keyserver-options http-proxy=http://3.39.86.231:8080/ --keyserver keyserver.ubuntu.com --recv-keys E84AC2C0460F3994
    if [[ `grep ceph02 /etc/hosts |wc -l` -lt 1 ]]; then
      echo "172.20.12.60 ceph01.crd.ge.com ceph01" >> /etc/hosts   
      echo "172.20.12.61 ceph02.crd.ge.com ceph02" >> /etc/hosts   
      echo "172.20.12.62 ceph03.crd.ge.com ceph03" >> /etc/hosts   
      echo "172.20.12.63 ceph04.crd.ge.com ceph04" >> /etc/hosts   
      echo "172.20.12.64 ceph05.crd.ge.com ceph05" >> /etc/hosts   
      echo "172.20.12.160 bootstrap.crd.ge.com bootstrap" >> /etc/hosts
      echo "172.20.13.160 zk-1" >>  /etc/hosts
      echo "172.20.13.161 zk-2" >>  /etc/hosts
      echo "172.20.13.162 zk-3" >>  /etc/hosts
    fi
    tee /etc/apt/sources.list.d/ceph.list <<-'EOF'
deb http://download.ceph.com/debian-hammer/ trusty main
# deb-src http://download.ceph.com/debian-hammer/ trusty main
EOF
    [[ -f /etc/apt/apt.conf ]] && mv /etc/apt/apt.conf  /etc/apt/apt.conf.saved
    apt-get  -y update; apt-get -y upgrade;apt-get -y install ntp selinux-utils policycoreutils ceph-common python-cephfs libcephfs1
    [[ ! `sestatus` =~ "disable" ]] && setenforce 0
    [[ `grep ^nogroup /etc/group|wc -l` -lt 1 ]] && groupadd -g 1001 nogroup
    if ! check_command_exists docker; then
        curl -fsSL https://get.docker.com/ | sh
        [[ ! -d /etc/systemd/system/docker.service.d ]] && mkdir -p /etc/systemd/system/docker.service.d
        [[ ! -d /usr/lib/systemd/system ]] && mkdir -p /usr/lib/systemd/system
    fi
    tee /etc/ceph/ceph.conf <<-'EOF'
[global]
        auth client required = none
        auth cluster required = none
        auth service required = none
        filestore xattr use omap = true
        debug_lockdep = 0/0
        debug_context = 0/0
        debug_crush = 0/0
        debug_buffer = 0/0
        debug_timer = 0/0
        debug_filer = 0/0
        debug_objecter = 0/0
        debug_rados = 0/0
        debug_rbd = 0/0
        debug_ms = 0/0
        debug_monc = 0/0
        debug_tp = 0/0
        debug_auth = 0/0
        debug_finisher = 0/0
        debug_heartbeatmap = 0/0
        debug_perfcounter = 0/0
        debug_asok = 0/0
        debug_throttle = 0/0
        debug_mon = 0/0
        debug_paxos = 0/0
        debug_rgw = 0/0
        perf = true
        mutex_perf_counter = true
        throttler_perf_counter = false
        # Haitao
        rbd cache = false
        log file = /var/log/ceph/$name.log
        log to syslog = false
        mon compact on trim = false
        osd pg bits = 8
        osd pgp bits = 8
        mon pg warn max object skew = 100000
        mon pg warn min per osd = 0
        mon pg warn max per osd = 32768
[mon]
        mon data =/home/haitao/tmp_cbt/ceph/mon.$id
        mon_max_pool_pg_num=166496
        mon_osd_max_split_count = 10000
        mon_pg_warn_max_per_osd = 10000
[osd]
       osd_mount_options_xfs = rw,noatime,inode64,logbsize=256k,delaylog
       osd_mkfs_options_xfs = -f -i size=2048
       osd_op_threads = 32
       filestore_queue_max_ops=5000
       filestore_queue_committing_max_ops=5000
       journal_max_write_entries=1000
       journal_queue_max_ops=3000
       objecter_inflight_ops=102400
       filestore_wbthrottle_enable=false
       filestore_queue_max_bytes=1048576000
       filestore_queue_committing_max_bytes=1048576000
       journal_max_write_bytes=1048576000
       journal_queue_max_bytes=1048576000
       ms_dispatch_throttle_bytes=1048576000
       objecter_infilght_op_bytes=1048576000
       osd_mkfs_type = xfs
       filestore_max_sync_interval=10
       osd_client_message_size_cap = 0
       osd_client_message_cap = 0
       osd_enable_op_tracker = false
       filestore_fd_cache_shards = 32
       filestore_fd_cache_size = 64
       filestore_op_threads = 6
       # Haitao: added per Jack
       osd_op_num_shards = 16                                                       
       osd_op_num_threads_per_shard = 2  
[mon.a]
        host = ceph01
        mon addr = 172.20.12.60:6789
[osd.0]
	host = ceph01
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-0-data
	osd journal = /dev/disk/by-partlabel/osd-device-0-journal
[osd.1]
	host = ceph01
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-1-data
	osd journal = /dev/disk/by-partlabel/osd-device-1-journal
[osd.2]
	host = ceph01
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-2-data
	osd journal = /dev/disk/by-partlabel/osd-device-2-journal
[osd.3]
	host = ceph01
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-3-data
	osd journal = /dev/disk/by-partlabel/osd-device-3-journal
[osd.4]
	host = ceph01
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-4-data
	osd journal = /dev/disk/by-partlabel/osd-device-4-journal
[osd.5]
	host = ceph01
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-5-data
	osd journal = /dev/disk/by-partlabel/osd-device-5-journal
[osd.6]
	host = ceph01
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-6-data
	osd journal = /dev/disk/by-partlabel/osd-device-6-journal
[osd.7]
	host = ceph01
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-7-data
	osd journal = /dev/disk/by-partlabel/osd-device-7-journal
[osd.8]
	host = ceph01
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-8-data
	osd journal = /dev/disk/by-partlabel/osd-device-8-journal
[osd.9]
	host = ceph01
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-9-data
	osd journal = /dev/disk/by-partlabel/osd-device-9-journal
[osd.10]
	host = ceph01
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-10-data
	osd journal = /dev/disk/by-partlabel/osd-device-10-journal
[osd.11]
	host = ceph01
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-11-data
	osd journal = /dev/disk/by-partlabel/osd-device-11-journal
[osd.12]
	host = ceph01
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-12-data
	osd journal = /dev/disk/by-partlabel/osd-device-12-journal
[osd.13]
	host = ceph01
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-13-data
	osd journal = /dev/disk/by-partlabel/osd-device-13-journal
[osd.14]
	host = ceph01
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-14-data
	osd journal = /dev/disk/by-partlabel/osd-device-14-journal
[osd.15]
	host = ceph01
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-15-data
	osd journal = /dev/disk/by-partlabel/osd-device-15-journal
[osd.16]
	host = ceph02
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-0-data
	osd journal = /dev/disk/by-partlabel/osd-device-0-journal
[osd.17]
	host = ceph02
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-1-data
	osd journal = /dev/disk/by-partlabel/osd-device-1-journal
[osd.18]
	host = ceph02
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-2-data
	osd journal = /dev/disk/by-partlabel/osd-device-2-journal
[osd.19]
	host = ceph02
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-3-data
	osd journal = /dev/disk/by-partlabel/osd-device-3-journal
[osd.20]
	host = ceph02
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-4-data
	osd journal = /dev/disk/by-partlabel/osd-device-4-journal
[osd.21]
	host = ceph02
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-5-data
	osd journal = /dev/disk/by-partlabel/osd-device-5-journal
[osd.22]
	host = ceph02
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-6-data
	osd journal = /dev/disk/by-partlabel/osd-device-6-journal
[osd.23]
	host = ceph02
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-7-data
	osd journal = /dev/disk/by-partlabel/osd-device-7-journal
[osd.24]
	host = ceph02
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-8-data
	osd journal = /dev/disk/by-partlabel/osd-device-8-journal
[osd.25]
	host = ceph02
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-9-data
	osd journal = /dev/disk/by-partlabel/osd-device-9-journal
[osd.26]
	host = ceph02
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-10-data
	osd journal = /dev/disk/by-partlabel/osd-device-10-journal
[osd.27]
	host = ceph02
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-11-data
	osd journal = /dev/disk/by-partlabel/osd-device-11-journal
[osd.28]
	host = ceph02
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-12-data
	osd journal = /dev/disk/by-partlabel/osd-device-12-journal
[osd.29]
	host = ceph02
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-13-data
	osd journal = /dev/disk/by-partlabel/osd-device-13-journal
[osd.30]
	host = ceph02
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-14-data
	osd journal = /dev/disk/by-partlabel/osd-device-14-journal
[osd.31]
	host = ceph02
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-15-data
	osd journal = /dev/disk/by-partlabel/osd-device-15-journal
[osd.32]
	host = ceph03
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-0-data
	osd journal = /dev/disk/by-partlabel/osd-device-0-journal
[osd.33]
	host = ceph03
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-1-data
	osd journal = /dev/disk/by-partlabel/osd-device-1-journal
[osd.34]
	host = ceph03
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-2-data
	osd journal = /dev/disk/by-partlabel/osd-device-2-journal
[osd.35]
	host = ceph03
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-3-data
	osd journal = /dev/disk/by-partlabel/osd-device-3-journal
[osd.36]
	host = ceph03
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-4-data
	osd journal = /dev/disk/by-partlabel/osd-device-4-journal
[osd.37]
	host = ceph03
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-5-data
	osd journal = /dev/disk/by-partlabel/osd-device-5-journal
[osd.38]
	host = ceph03
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-6-data
	osd journal = /dev/disk/by-partlabel/osd-device-6-journal
[osd.39]
	host = ceph03
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-7-data
	osd journal = /dev/disk/by-partlabel/osd-device-7-journal
[osd.40]
	host = ceph03
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-8-data
	osd journal = /dev/disk/by-partlabel/osd-device-8-journal
[osd.41]
	host = ceph03
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-9-data
	osd journal = /dev/disk/by-partlabel/osd-device-9-journal
[osd.42]
	host = ceph03
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-10-data
	osd journal = /dev/disk/by-partlabel/osd-device-10-journal
[osd.43]
	host = ceph03
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-11-data
	osd journal = /dev/disk/by-partlabel/osd-device-11-journal
[osd.44]
	host = ceph03
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-12-data
	osd journal = /dev/disk/by-partlabel/osd-device-12-journal
[osd.45]
	host = ceph03
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-13-data
	osd journal = /dev/disk/by-partlabel/osd-device-13-journal
[osd.46]
	host = ceph03
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-14-data
	osd journal = /dev/disk/by-partlabel/osd-device-14-journal
[osd.47]
	host = ceph03
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-15-data
	osd journal = /dev/disk/by-partlabel/osd-device-15-journal
[osd.48]
	host = ceph04
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-0-data
	osd journal = /dev/disk/by-partlabel/osd-device-0-journal
[osd.49]
	host = ceph04
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-1-data
	osd journal = /dev/disk/by-partlabel/osd-device-1-journal
[osd.50]
	host = ceph04
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-2-data
	osd journal = /dev/disk/by-partlabel/osd-device-2-journal
[osd.51]
	host = ceph04
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-3-data
	osd journal = /dev/disk/by-partlabel/osd-device-3-journal
[osd.52]
	host = ceph04
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-4-data
	osd journal = /dev/disk/by-partlabel/osd-device-4-journal
[osd.53]
	host = ceph04
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-5-data
	osd journal = /dev/disk/by-partlabel/osd-device-5-journal
[osd.54]
	host = ceph04
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-6-data
	osd journal = /dev/disk/by-partlabel/osd-device-6-journal
[osd.55]
	host = ceph04
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-7-data
	osd journal = /dev/disk/by-partlabel/osd-device-7-journal
[osd.56]
	host = ceph04
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-8-data
	osd journal = /dev/disk/by-partlabel/osd-device-8-journal
[osd.57]
	host = ceph04
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-9-data
	osd journal = /dev/disk/by-partlabel/osd-device-9-journal
[osd.58]
	host = ceph04
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-10-data
	osd journal = /dev/disk/by-partlabel/osd-device-10-journal
[osd.59]
	host = ceph04
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-11-data
	osd journal = /dev/disk/by-partlabel/osd-device-11-journal
[osd.60]
	host = ceph04
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-12-data
	osd journal = /dev/disk/by-partlabel/osd-device-12-journal
[osd.61]
	host = ceph04
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-13-data
	osd journal = /dev/disk/by-partlabel/osd-device-13-journal
[osd.62]
	host = ceph04
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-14-data
	osd journal = /dev/disk/by-partlabel/osd-device-14-journal
[osd.63]
	host = ceph04
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-15-data
	osd journal = /dev/disk/by-partlabel/osd-device-15-journal
[osd.64]
	host = ceph05
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-0-data
	osd journal = /dev/disk/by-partlabel/osd-device-0-journal
[osd.65]
	host = ceph05
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-1-data
	osd journal = /dev/disk/by-partlabel/osd-device-1-journal
[osd.66]
	host = ceph05
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-2-data
	osd journal = /dev/disk/by-partlabel/osd-device-2-journal
[osd.67]
	host = ceph05
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-3-data
	osd journal = /dev/disk/by-partlabel/osd-device-3-journal
[osd.68]
	host = ceph05
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-4-data
	osd journal = /dev/disk/by-partlabel/osd-device-4-journal
[osd.69]
	host = ceph05
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-5-data
	osd journal = /dev/disk/by-partlabel/osd-device-5-journal
[osd.70]
	host = ceph05
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-6-data
	osd journal = /dev/disk/by-partlabel/osd-device-6-journal
[osd.71]
	host = ceph05
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-7-data
	osd journal = /dev/disk/by-partlabel/osd-device-7-journal
[osd.72]
	host = ceph05
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-8-data
	osd journal = /dev/disk/by-partlabel/osd-device-8-journal
[osd.73]
	host = ceph05
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-9-data
	osd journal = /dev/disk/by-partlabel/osd-device-9-journal
[osd.74]
	host = ceph05
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-10-data
	osd journal = /dev/disk/by-partlabel/osd-device-10-journal
[osd.75]
	host = ceph05
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-11-data
	osd journal = /dev/disk/by-partlabel/osd-device-11-journal
[osd.76]
	host = ceph05
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-12-data
	osd journal = /dev/disk/by-partlabel/osd-device-12-journal
[osd.77]
	host = ceph05
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-13-data
	osd journal = /dev/disk/by-partlabel/osd-device-13-journal
[osd.78]
	host = ceph05
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-14-data
	osd journal = /dev/disk/by-partlabel/osd-device-14-journal
[osd.79]
	host = ceph05
	osd data = /home/haitao/tmp_cbt/mnt/osd-device-15-data
	osd journal = /dev/disk/by-partlabel/osd-device-15-journal 
EOF
    NIC=$(ip addr| grep 'state UP'| grep -v lo| cut -d: -f2| sed 's/^\s//'|head -1)
    THIS_IP=$(ip addr show ${NIC} | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
    #tee /etc/systemd/system/docker.service.d/override.conf  <<-'EOF'
    cat << EOF > "/etc/systemd/system/docker.service.d/override.conf"
[Service]
ExecStart=
ExecStart=/usr/bin/docker daemon --storage-driver=overlay --storage-opt dm.no_warn_on_loop_devices=true -H fd:// -H tcp://0.0.0.0:4243  --insecure-registry bootstrap.crd.ge.com:5000 --cluster-store=zk://zk-1:2181,zk-2:2181,zk-3:2181 --cluster-advertise=${THIS_IP}:2376
EOF
    tee /etc/systemd/system/docker.service.d/http-ptoxy.conf <<-'EOF'
[Service]
Environment="HTTP_PROXY=http://3.39.86.231:8080/" "HTTPS_PROXY=http://3.39.86.231:8080/" "NO_PROXY=localhost,127.0.0.1,bootstrap.crd.ge.com"
EOF
    tee /usr/lib/systemd/system/docker.socket <<-'EOF'
[Unit]
Description=Docker Socket for the API
PartOf=docker.service
[Socket]
ListenStream=/var/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker
[Install]
WantedBy=sockets.target
EOF
    systemctl daemon-reload
    systemctl enable  docker.socket
    systemctl enable  docker
    systemctl restart docker.socket
    systemctl restart docker
    systemctl restart ntp
}


function usage()
{
    echo -e "${BOLD}Usage: $0 [--disable-preflight|--preflight-only] <roles>${NORMAL}"
}
function main()
{
    eval set -- "$ARGS"
    while true ; do
        case "$1" in
            -d|--disable-preflight) DISABLE_PREFLIGHT=1;  shift  ;;
            -p|--preflight-only) PREFLIGHT_ONLY=1 ; shift  ;;
            --no-block-dcos-setup) SYSTEMCTL_NO_BLOCK=1;  shift ;;
            -h|--help) usage; exit 1 ;;
            --) shift ; break ;;
            *) usage ; exit 1 ;;
        esac
    done
    shift $(($OPTIND - 1))
    ROLES=$@
    export http_proxy=http://3.39.86.231:8080
    export https_proxy=http://3.39.86.231:8080
cat <<'EOF' > /etc/resolv.conf
nameserver 3.1.7.107 
nameserver 3.1.6.27
search crd.ge.com logon.ds.ge.com
EOF
    #
    # update proxy cert for external pulls
    #
cat <<'EOF' > /usr/share/ca-certificates/mozilla/GE_External_Root_CA_2.crt
-----BEGIN CERTIFICATE-----
-----END CERTIFICATE-----
EOF
cat <<'EOF' > /usr/share/ca-certificates/mozilla/GE_External_Root_CA_2_1.crt
-----BEGIN CERTIFICATE-----
-----END CERTIFICATE-----
EOF
[[ `grep -i GE_External_Root_CA_2.crt /etc/ca-certificates.conf | wc -l` -lt 1 ]] && echo "mozilla/GE_External_Root_CA_2.crt" >> /etc/ca-certificates.conf
[[ `grep -i GE_External_Root_CA_2_1.crt /etc/ca-certificates.conf | wc -l` -lt 1 ]] && echo "mozilla/GE_External_Root_CA_2_1.crt" >> /etc/ca-certificates.conf
update-ca-certificates

    pre_requisite
}
# Run it all
main


