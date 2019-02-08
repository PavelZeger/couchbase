# Restoring sample data
/opt/couchbase/bin/cbdocloader -n localhost:8091 -u admin -p naya2019! -b travel-sample -s 100 /opt/couchbase/samples/travel-sample.zip
/opt/couchbase/bin/cbdocloader -n localhost:8091 -u admin -p naya2019! -b gamesim-sample -s 100 /opt/couchbase/samples/gamesim-sample.zip
/opt/couchbase/bin/cbdocloader -n localhost:8091 -u admin -p naya2019! -b beer-sample -s 100 /opt/couchbase/samples/beer-sample.zip

# Community edition
/opt/couchbase/bin/cbbackup http://172.20.100.115:8091 /root/backup -u admin -p naya2019!
/opt/couchbase/bin/cbbackup http://172.20.100.115:8091 /root/backup -m diff -u admin -p naya2019!
/opt/couchbase/bin/cbbackup http://172.20.100.115:8091 /root/backup -m diff -u admin -p naya2019!

/opt/couchbase/bin/cbbackup couchbase://172.20.100.115:8091 /root/backup -m full --single-node -u admin -p naya2019!
/opt/couchbase/bin/cbbackup couchbase://172.20.100.115:8091 /root/backup -m diff --single-node -u admin -p naya2019!
/opt/couchbase/bin/cbbackup couchbase://172.20.100.115:8091 /root/backup -m diff --single-node -u admin -p naya2019!
/opt/couchbase/bin/cbbackup couchbase://172.20.100.115:8091 /root/backup -m accu --single-node -u admin -p naya2019!

# Enterprise edition
/opt/couchbase/bin/cbbackupmgr config -a /root/backup -r leader_capital_cluster_backup



