#!/usr/bin/perl -w
#
#
# This program implements a SNMP agent for MySQL servers
#
# (c) Copryright 2008, 2009 - Brice Figureau
#
# The INNODB parsing code is originally Copyright 2008 Baron Schwartz,
# and was released as GPL,v2.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.    See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.    If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use Data::Dumper;
use Unix::Syslog qw(:subs :macros);
use Getopt::Long;
use POSIX qw( setsid );
use NetSNMP::OID (':all');
use NetSNMP::agent(':all');
use NetSNMP::ASN(':all');
use NetSNMP::agent::default_store;
use NetSNMP::default_store qw(:all);
use SNMP;
use DBI;
use DBD::mysql;
use Pod::Usage;

sub my_snmp_handler($$$$);
netsnmp_ds_set_boolean( NETSNMP_DS_APPLICATION_ID,
    NETSNMP_DS_AGENT_NO_ROOT_ACCESS, 1 );
my $agent = new NetSNMP::agent( 'Name' => 'mysql', 'AgentX' => 1 );

my $VERSION = "0.6";

my %opt = (
    daemon_pid  => '/var/run/mysql-agent.pid',
    host        => 'localhost',
    oid         => '1.3.6.1.4.1.20267.200.1',
    pass        => '',
    port        => '3306',
    refresh     => '300',
    user        => 'monitor',
);

Getopt::Long::Configure('no_ignore_case');
GetOptions(
    \%opt,
    'daemon_pid|daemon-pid=s',
    'help|?',
    'host=s',
    'man',
    'master|m',
    'no-daemon',
    'oid',
    'password=s',
    'port|P=i',
    'refresh|i=i',
    'slave',
    'user=s',
    'usage',
    'verbose|v+',    
    'version|V',
) or pod2usage(-verbose => 0);

pod2usage(-verbose => 0) if $opt{usage};
pod2usage(-verbose => 1) if $opt{help};
pod2usage(-verbose => 2) if $opt{man};

if ( $opt{version} ) {
    print "mysql-agent.pl $VERSION by brice.figureau\@daysofwonder.com\n";
    exit;
}

my $debugging      = $opt{verbose};
my $subagent       = 0;
my $chk_innodb = 1;    # Do you want to check InnoDB statistics?
my $chk_master = 1;    # Do you want to check binary logging?
my $chk_slave  = 0;    # Do you want to check slave status?

my $dsn     = "DBI:mysql:host=$opt{host};port=$opt{port}";
my $running = 0;
my $error   = 0;

# prototypes
sub daemonize();
sub dolog($$);

openlog( "mysql-agent", LOG_PID | LOG_PERROR, LOG_DAEMON );

daemonize() if !$opt{'no-daemon'};

my %global_status       = ();
my $global_last_refresh = 0;

# enterprises.20267.200.1
my $regOID = new NetSNMP::OID($opt{oid});
$agent->register( "mysql", $regOID, \&my_snmp_handler );

# various types & definitions
my @types = (
    'Counter32', 'Counter32', 'Counter32', 'Counter32',
    'Gauge32',   'Counter64', 'Gauge32',   'Gauge32',
    'Gauge32',   'Gauge32',   'Gauge32',   'Gauge32',
    'Gauge32',   'Gauge32',   'Counter32', 'Counter32',
    'Counter32', 'Counter32', 'Counter32', 'Counter32',
    'Counter32', 'Gauge32',   'Gauge32',   'Gauge32',
    'Gauge32',   'Gauge32',   'Gauge32',   'Gauge32',
    'Gauge32',   'Gauge32',   'Counter32', 'Counter32',
    'Counter32', 'Counter32', 'Counter32', 'Counter32',
    'Counter32', 'Counter32', 'Counter32', 'Counter32',
    'Counter32', 'Counter32', 'Counter32', 'Gauge32',
    'Gauge32',   'Counter32', 'Counter32', 'Counter32',
    'Counter32', 'Counter32', 'Counter32', 'Counter32',
    'Counter32', 'Gauge32',   'Gauge32',   'Counter32',
    'Gauge32',   'Gauge32',   'Gauge32',   'Counter32',
    'Gauge32',   'Gauge32',   'Counter32', 'Gauge32',
    'Gauge32',   'Gauge32',   'Gauge32',   'Counter32',
    'Counter32', 'Counter32', 'Counter32', 'Gauge32',
    'Gauge32',   'Counter32', 'Counter32', 'Counter32',
    'Counter32', 'Counter32', 'Counter32', 'Counter32',
    'Counter32', 'Counter32', 'Counter32', 'Counter32',
    'Counter32', 'Counter32', 'Counter32', 'Counter32',
    'Counter32', 'Counter32', 'Counter32', 'Counter32',
    'Counter32', 'Counter32', 'Counter32', 'Counter32',
    'Counter32', 'Counter32', 'Counter32', 'Gauge32',
    'Gauge32',   'Counter64', 'Counter64', 'Counter32',
    'Gauge32',   'Counter32', 'Counter32', 'Counter32',
);

my @newkeys = (
    'myKeyReadRequests',          'myKeyReads',
    'myKeyWriteRequests',         'myKeyWrites',
    'myHistoryList',              'myInnodbTransactions',
    'myReadViews',                'myCurrentTransactions',
    'myLockedTransactions',       'myActiveTransactions',
    'myPoolSize',                 'myFreePages',
    'myDatabasePages',            'myModifiedPages',
    'myPagesRead',                'myPagesCreated',
    'myPagesWritten',             'myFileFsyncs',
    'myFileReads',                'myFileWrites',
    'myLogWrites',                'myPendingAIOLogIOs',
    'myPendingAIOSyncIOs',        'myPendingBufPoolFlushes',
    'myPendingChkpWrites',        'myPendingIbufAIOReads',
    'myPendingLogFlushes',        'myPendingLogWrites',
    'myPendingNormalAIOReads',    'myPendingNormalAIOWrites',
    'myIbufInserts',              'myIbufMerged',
    'myIbufMerges',               'mySpinWaits',
    'mySpinRounds',               'myOsWaits',
    'myRowsInserted',             'myRowsUpdated',
    'myRowsDeleted',              'myRowsRead',
    'myTableLocksWaited',         'myTableLocksImmediate',
    'mySlowQueries',              'myOpenFiles',
    'myOpenTables',               'myOpenedTables',
    'myInnodbOpenFiles',          'myOpenFilesLimit',
    'myTableCache',               'myAbortedClients',
    'myAbortedConnects',          'myMaxUsedConnections',
    'mySlowLaunchThreads',        'myThreadsCached',
    'myThreadsConnected',         'myThreadsCreated',
    'myThreadsRunning',           'myMaxConnections',
    'myThreadCacheSize',          'myConnections',
    'mySlaveRunning',             'mySlaveStopped',
    'mySlaveRetriedTransactions', 'mySlaveLag',
    'mySlaveOpenTempTables',      'myQcacheFreeBlocks',
    'myQcacheFreeMemory',         'myQcacheHits',
    'myQcacheInserts',            'myQcacheLowmemPrunes',
    'myQcacheNotCached',          'myQcacheQueriesInCache',
    'myQcacheTotalBlocks',        'myQueryCacheSize',
    'myQuestions',                'myComUpdate',
    'myComInsert',                'myComSelect',
    'myComDelete',                'myComReplace',
    'myComLoad',                  'myComUpdateMulti',
    'myComInsertSelect',          'myComDeleteMulti',
    'myComReplaceSelect',         'mySelectFullJoin',
    'mySelectFullRangeJoin',      'mySelectRange',
    'mySelectRangeCheck',         'mySelectScan',
    'mySortMergePasses',          'mySortRange',
    'mySortRows',                 'mySortScan',
    'myCreatedTmpTables',         'myCreatedTmpDiskTables',
    'myCreatedTmpFiles',          'myBytesSent',
    'myBytesReceived',            'myInnodbLogBufferSize',
    'myUnflushedLog',             'myLogBytesFlushed',
    'myLogBytesWritten',          'myRelayLogSpace',
    'myBinlogCacheSize',          'myBinlogCacheDiskUse',
    'myBinlogCacheUse',           'myBinaryLogSpace',
);

my @oldkeys = (
    'Key_read_requests',          'Key_reads',
    'Key_write_requests',         'Key_writes',
    'history_list',               'innodb_transactions',
    'read_views',                 'current_transactions',
    'locked_transactions',        'active_transactions',
    'pool_size',                  'free_pages',
    'database_pages',             'modified_pages',
    'pages_read',                 'pages_created',
    'pages_written',              'file_fsyncs',
    'file_reads',                 'file_writes',
    'log_writes',                 'pending_aio_log_ios',
    'pending_aio_sync_ios',       'pending_buf_pool_flushes',
    'pending_chkp_writes',        'pending_ibuf_aio_reads',
    'pending_log_flushes',        'pending_log_writes',
    'pending_normal_aio_reads',   'pending_normal_aio_writes',
    'ibuf_inserts',               'ibuf_merged',
    'ibuf_merges',                'spin_waits',
    'spin_rounds',                'os_waits',
    'rows_inserted',              'rows_updated',
    'rows_deleted',               'rows_read',
    'Table_locks_waited',         'Table_locks_immediate',
    'Slow_queries',               'Open_files',
    'Open_tables',                'Opened_tables',
    'innodb_open_files',          'open_files_limit',
    'table_cache',                'Aborted_clients',
    'Aborted_connects',           'Max_used_connections',
    'Slow_launch_threads',        'Threads_cached',
    'Threads_connected',          'Threads_created',
    'Threads_running',            'max_connections',
    'thread_cache_size',          'Connections',
    'slave_running',              'slave_stopped',
    'Slave_retried_transactions', 'slave_lag',
    'Slave_open_temp_tables',     'Qcache_free_blocks',
    'Qcache_free_memory',         'Qcache_hits',
    'Qcache_inserts',             'Qcache_lowmem_prunes',
    'Qcache_not_cached',          'Qcache_queries_in_cache',
    'Qcache_total_blocks',        'query_cache_size',
    'Questions',                  'Com_update',
    'Com_insert',                 'Com_select',
    'Com_delete',                 'Com_replace',
    'Com_load',                   'Com_update_multi',
    'Com_insert_select',          'Com_delete_multi',
    'Com_replace_select',         'Select_full_join',
    'Select_full_range_join',     'Select_range',
    'Select_range_check',         'Select_scan',
    'Sort_merge_passes',          'Sort_range',
    'Sort_rows',                  'Sort_scan',
    'Created_tmp_tables',         'Created_tmp_disk_tables',
    'Created_tmp_files',          'Bytes_sent',
    'Bytes_received',             'innodb_log_buffer_size',
    'unflushed_log',              'log_bytes_flushed',
    'log_bytes_written',          'relay_log_space',
    'binlog_cache_size',          'Binlog_cache_disk_use',
    'Binlog_cache_use',           'binary_log_space',
);

# this will hold a table of conversion between numerical oids and oidnames
my %oids = ();

# build the oids table
my $i = 1;
foreach my $oidname (@newkeys) {
    $oids{ $regOID . ".$i.0" } = {
        'name' => $oidname,
        'oid'  => new NetSNMP::OID( $regOID . ".$i.0" )
    };
    $i++;
}

# this contains a lexicographycally sorted oids array
my @ks = sort { $a <=> $b } map { $_ = new NetSNMP::OID($_) } keys %oids;
my $lowestOid  = $ks[0];
my $highestOid = $ks[$#ks];

if ($debugging) {
    foreach my $k (@ks) {
        dolog( LOG_DEBUG, "$k -> " . $oids{$k}->{'name'} );
    }
}

# takes only numbers from a string
sub tonum ($) {
    my $str = shift;
    return 0 if !$str;
    return $1 if $str =~ m/(\d+)/;
    return 0;
}

# return a string to build a 64 bit number
sub make_bigint_sql ($$) {
    my $hi = shift;
    my $lo = shift;
    return "(($hi << 32) + $lo)";
}

sub max($$) {
    my $a = shift;
    my $b = shift;
    return $a if $a > $b;
    return $b;
}

# daemonize the program
sub daemonize() {
    open STDIN, '/dev/null' or die "mysql-agent: can't read /dev/null: $!";
    open STDOUT, '>/dev/null'
        or die "mysql-agent: can't write to /dev/null: $!";
    defined( my $pid = fork ) or die "mysql-agent: can't fork: $!";
    if ($pid) {

        # parent
        open PIDFILE, '>', $opt{daemon_pidfile}
            or die "$0: can't write to $opt{daemon_pidfile}: $!\n";
        print PIDFILE "$pid\n";
        close(PIDFILE);
        exit;
    }

    # child
    setsid() or die "mysql-agent: can't start a new session: $!";
    open STDERR, '>&STDOUT' or die "mysql-agent: can't dup stdout: $!";
}

# This function has been translated from PHP to Perl from the
# excellent Baron Schwartz's MySQL Cacti Templates
sub fetch_mysql_data {
    my ( $datasource, $dbuser, $dbpass ) = @_;
    my %output;
    eval {
        my $dbh
            = DBI->connect( $datasource, $dbuser, $dbpass,
            { RaiseError => 1, AutoCommit => 1 } );

        if ( !$dbh ) {
            dolog( LOG_CRIT, "Can't connect to database: $datasource, $@" );
            return;
        }

        my %status = (
            'transactions'         => 0,
            'relay_log_space'      => 0,
            'binary_log_space'     => 0,
            'current_transactions' => 0,
            'locked_transactions'  => 0,
            'active_transactions'  => 0,
            'slave_lag'            => 0,
            'slave_running'        => 0,
            'slave_stopped'        => 0
        );

        my $result
            = $dbh->selectall_arrayref("SHOW /*!50002 GLOBAL */ STATUS");
        foreach my $row (@$result) {
            $status{ $row->[0] } = $row->[1];
        }

        # Get SHOW VARIABLES and convert the name-value array into a simple
        # associative array.
        $result = $dbh->selectall_arrayref("SHOW VARIABLES");
        foreach my $row (@$result) {
            $status{ $row->[0] } = $row->[1];
        }

        if ($chk_slave) {
            $result = $dbh->selectall_arrayref("SHOW SLAVE STATUS");
            foreach my $row (@$result) {

               # Must lowercase keys because different versions have different
               # lettercase.
                $row = map { lc($_) => $row->{$_} } keys %$row;
                $status{'relay_log_space'} = $row->{'relay_log_space'};
                $status{'slave_lag'}       = $row->{'seconds_behind_master'};

      # Check replication heartbeat, if present.
      # if ( $hb_table ) {
      #     $result = run_query(
      #        "SELECT GREATEST(0, UNIX_TIMESTAMP() - UNIX_TIMESTAMP(ts) - 1)"
      #        . "FROM $hb_table WHERE id = 1", $conn);
      #     $row2 = @mysql_fetch_row($result);
      #     $status{'slave_lag'} = $row2[0];
      # }

            # Scale slave_running and slave_stopped relative to the slave lag.
                $status{'slave_running'}
                    = ( $row->{'slave_sql_running'} == 'Yes' )
                    ? $status{'slave_lag'}
                    : 0;
                $status{'slave_stopped'}
                    = ( $row->{'slave_sql_running'} == 'Yes' )
                    ? 0
                    : $status{'slave_lag'};
            }
        }

        # Get info on master logs.
        my @binlogs = (0);
        if ( $chk_master && $status{'log_bin'} eq 'ON' ) {    # See issue #8
            $result = $dbh->selectall_arrayref( "SHOW MASTER LOGS",
                { Slice => {} } );
            foreach my $row (@$result) {
                my %newrow = map { lc($_) => $row->{$_} } keys %$row;

            # Older versions of MySQL may not have the File_size column in the
            # results of the command.
                if ( exists( $newrow{'file_size'} ) ) {
                    push( @binlogs, $newrow{'file_size'} );
                }
                else {
                    last;
                }
            }
        }

        # Get SHOW INNODB STATUS and extract the desired metrics from it.
        my @innodb_txn = ();
        my @flushed_to = ();
        my @innodb_lsn = ();
        my @innodb_prg = ();
        my @spin_waits;
        my @spin_rounds;
        my @os_waits;

        if ( $chk_innodb && $status{'have_innodb'} eq 'YES' ) {
            my $innodb_array
                = $dbh->selectall_arrayref(
                "SHOW /*!50000 ENGINE*/ INNODB STATUS",
                { Slice => {} } );
            my @lines = split( "\n", $innodb_array->[0]{'Status'} );

            foreach my $line (@lines) {
                my @row = split( / +/, $line );

                # SEMAPHORES
                if ( $line =~ m/Mutex spin waits/ ) {
                    push( @spin_waits,  tonum( $row[3] ) );
                    push( @spin_rounds, tonum( $row[5] ) );
                    push( @os_waits,    tonum( $row[8] ) );
                }
                elsif ( $line =~ m/RW-shared spins/ ) {
                    push( @spin_waits, tonum( $row[2] ) );
                    push( @spin_waits, tonum( $row[8] ) );
                    push( @os_waits,   tonum( $row[5] ) );
                    push( @os_waits,   tonum( $row[11] ) );
                }

                # TRANSACTIONS
                elsif ( $line =~ m/Trx id counter/ ) {

                   # The beginning of the TRANSACTIONS section: start counting
                   # transactions
                    @innodb_txn = ( $row[3], $row[4] );
                }
                elsif ( $line =~ m/Purge done for trx/ ) {

                    # PHP can't do big math, so I send it to MySQL.
                    @innodb_prg = ( $row[6], $row[7] );
                }
                elsif ( $line =~ m/History list length/ ) {
                    $status{'history_list'} = tonum( $row[3] );
                }
                elsif ( $#innodb_txn > 0 && $line =~ m/---TRANSACTION/ ) {
                    $status{'current_transactions'} += 1;
                    if ( $line =~ m/ACTIVE/ ) {
                        $status{'active_transactions'} += 1;
                    }
                }
                elsif ( $#innodb_txn > 0 && $line =~ m/LOCK WAIT/ ) {
                    $status{'locked_transactions'} += 1;
                }
                elsif ( $line =~ m/read views open inside/ ) {
                    $status{'read_views'} = tonum( $row[0] );
                }

                # FILE I/O
                elsif ( $line =~ m/OS file reads/ ) {
                    $status{'file_reads'}  = tonum( $row[0] );
                    $status{'file_writes'} = tonum( $row[4] );
                    $status{'file_fsyncs'} = tonum( $row[8] );
                }
                elsif ( $line =~ m/Pending normal aio/ ) {
                    $status{'pending_normal_aio_reads'}  = tonum( $row[4] );
                    $status{'pending_normal_aio_writes'} = tonum( $row[7] );
                }
                elsif ( $line =~ m/ibuf aio reads/ ) {
                    $status{'pending_ibuf_aio_reads'} = tonum( $row[4] );
                    $status{'pending_aio_log_ios'}    = tonum( $row[7] );
                    $status{'pending_aio_sync_ios'}   = tonum( $row[10] );
                }
                elsif ( $line =~ m/Pending flushes \(fsync\)/ ) {
                    $status{'pending_log_flushes'}      = tonum( $row[4] );
                    $status{'pending_buf_pool_flushes'} = tonum( $row[7] );
                }

                # INSERT BUFFER AND ADAPTIVE HASH INDEX
                elsif ( $line =~ m/merged recs/ ) {
                    $status{'ibuf_inserts'} = tonum( $row[0] );
                    $status{'ibuf_merged'}  = tonum( $row[2] );
                    $status{'ibuf_merges'}  = tonum( $row[5] );
                }

                # LOG
                elsif ( $line =~ m/log i\/o's done/ ) {    #'
                    $status{'log_writes'} = tonum( $row[0] );
                }
                elsif ( $line =~ m/pending log writes/ ) {
                    $status{'pending_log_writes'}  = tonum( $row[0] );
                    $status{'pending_chkp_writes'} = tonum( $row[4] );
                }
                elsif ( $line =~ m/Log sequence number/ ) {
                    @innodb_lsn = ( $row[3], $row[4] );
                }
                elsif ( $line =~ m/Log flushed up to/ ) {

         # Since PHP can't handle 64-bit numbers, we'll ask MySQL to do it for
         # us instead.    And we get it to cast them to strings, too.
                    @flushed_to = ( $row[4], $row[5] );
                }

                # BUFFER POOL AND MEMORY
                elsif ( $line =~ m/Buffer pool size/ ) {
                    $status{'pool_size'} = tonum( $row[3] );
                }
                elsif ( $line =~ m/Free buffers/ ) {
                    $status{'free_pages'} = tonum( $row[2] );
                }
                elsif ( $line =~ m/Database pages/ ) {
                    $status{'database_pages'} = tonum( $row[2] );
                }
                elsif ( $line =~ m/Modified db pages/ ) {
                    $status{'modified_pages'} = tonum( $row[3] );
                }
                elsif ( $line =~ m/Pages read/ ) {
                    $status{'pages_read'}    = tonum( $row[2] );
                    $status{'pages_created'} = tonum( $row[4] );
                    $status{'pages_written'} = tonum( $row[6] );
                }

                # ROW OPERATIONS
                elsif ( $line =~ m/Number of rows inserted/ ) {
                    $status{'rows_inserted'} = tonum( $row[4] );
                    $status{'rows_updated'}  = tonum( $row[6] );
                    $status{'rows_deleted'}  = tonum( $row[8] );
                    $status{'rows_read'}     = tonum( $row[10] );
                }
                elsif ( $line =~ m/queries inside InnoDB/ ) {
                    $status{'queries_inside'} = tonum( $row[0] );
                    $status{'queries_queued'} = tonum( $row[4] );
                }
            }
        }

        # Derive some values from other values.

      # PHP sucks at bigint math, so we use MySQL to calculate things that are
      # too big for it.
        if ($#innodb_txn) {
            my $txn = make_bigint_sql( $innodb_txn[0], $innodb_txn[1] );
            my $lsn = make_bigint_sql( $innodb_lsn[0], $innodb_lsn[1] );
            my $flu = make_bigint_sql( $flushed_to[0], $flushed_to[1] );
            my $prg = make_bigint_sql( $innodb_prg[0], $innodb_prg[1] );
            my $sql
                = "SELECT CONCAT('', $txn) AS innodb_transactions, "
                . "CONCAT('', ($txn - $prg)) AS unpurged_txns, "
                . "CONCAT('', $lsn) AS log_bytes_written, "
                . "CONCAT('', $flu) AS log_bytes_flushed, "
                . "CONCAT('', ($lsn - $flu)) AS unflushed_log, "
                . "CONCAT('', "
                . join( '+', @spin_waits )
                . ") AS spin_waits, "
                . "CONCAT('', "
                . join( '+', @spin_rounds )
                . ") AS spin_rounds, "
                . "CONCAT('', "
                . join( '+', @os_waits )
                . ") AS os_waits";
            $result = $dbh->selectall_arrayref( $sql, { Slice => {} } );
            foreach my $row (@$result) {
                foreach my $key ( keys %$row ) {
                    $status{$key} = $row->{$key};
                }
            }
            $status{'unflushed_log'} = max( $status{'unflushed_log'},
                $status{'innodb_log_buffer_size'} );
        }
        if ($#binlogs) {
            my $sql
                = "SELECT "
                . "CONCAT('', "
                . join( '+', @binlogs )
                . ") AS binary_log_space ";

            # echo("$sql\n");
            $result = $dbh->selectall_arrayref( $sql, { Slice => {} } );
            foreach my $row (@$result) {
                foreach my $key ( keys %$row ) {
                    $status{$key} = $row->{$key};
                }
            }
        }

        $dbh->disconnect();

        my %trans;
        my $i = 0;
        foreach my $key (@oldkeys) {
            $trans{$key} = $newkeys[ $i++ ];
        }

        foreach my $key ( keys %status ) {

            #print "key $key\n";
            $output{ $trans{$key} } = $status{$key}
                if ( exists( $trans{$key} ) );
        }
    };
    if ($@) {
        dolog( LOG_CRIT, "can't refresh data from mysql: $@\n" );
        return ( undef, undef, undef );
    }
    return ( \@newkeys, \@types, \%output );
}

###
### Called automatically now and then
### Refreshes the $global_status and $global_variables
### caches.
###
sub refresh_status {
    my $startOID = shift;
    my $now      = time();

    # Check if we have been called quicker than once every $refresh_interval
    if ( ( $now - $global_last_refresh ) < $opt{refresh_interval} ) {

        # if yes, do not do anything
        dolog( LOG_DEBUG,
                  "not refreshing: "
                . ( $now - $global_last_refresh )
                . " < $opt{refresh_interval}" )
            if ($debugging);
        return;
    }
    my ( $oid, $types, $status ) = fetch_mysql_data( $dsn, $opt{user}, $opt{pass} );
    if ($oid) {
        dolog( LOG_DEBUG, "Setting error to 0" ) if ($debugging);
        $error = 0;
        my $index = 0;
        foreach my $key (@$oid) {
            $global_status{$key}{'value'} = $status->{$key};
            $global_status{$key}{'type'}  = $types->[$index];
            $index++;
        }
        dolog( LOG_DEBUG, "Refreshed at $now " . ( time() - $now ) )
            if ($debugging);
        print Dumper( \%global_status ) if ($debugging);
    }
    else {
        dolog( LOG_DEBUG, "Setting error to 1" ) if ($debugging);
        $error = 1;
    }

    $global_last_refresh = $now;
    return;
}

sub getASNType {
    my $type = shift;
    if ( $type eq 'Counter32' ) {
        return ASN_COUNTER;
    }
    elsif ( $type eq 'Gauge32' ) {
        return ASN_GAUGE;
    }
    elsif ( $type eq 'Counter64' ) {
        return ASN_COUNTER64;
    }
    elsif ( $type eq 'OID' ) {
        return ASN_OBJECT_ID;
    }
    return ASN_OCTET_STR;
}

sub shut_it_down {
    $running = 0;
    dolog( LOG_INFO, "shutting down" );
}

sub set_value {
    my ( $request, $oid ) = @_;

    if ( !$error ) {
        my $oidname = $oids{$oid}->{'name'};
        if ( !defined $oidname ) {
            dolog( LOG_ERR, "Error finding a oidname for $oid" );
            return;
        }

        my $value = $global_status{$oidname}{'value'};
        if ( defined $value ) {
            if ($debugging) {
                dolog( LOG_DEBUG, "$oid -> $lowestOid" );
                dolog( LOG_DEBUG, "  -> ($oidname) $value" );
            }
            $request->setOID($oid);
            $request->setValue(
                getASNType( $global_status{$oidname}{'type'} ), "$value" );
        }
        else {
            dolog( LOG_ERR, "Error getting value $oidname for $oid" );
        }
    }
}

sub my_snmp_handler($$$$) {
    my ( $handler, $registration_info, $request_info, $requests ) = @_;
    my ($request);

#  print STDERR "refs: ",join(", ", ref($handler), ref($registration_info),
#                             ref($request_info), ref($requests)),"\n" if ($debugging);

    for ( $request = $requests; $request; $request = $request->next() ) {

        # Process request for $oid (e.g. mysqlUptime)
        my $oid  = $request->getOID();
        my $mode = $request_info->getMode();
        my $value;
        my $next;

        dolog( LOG_DEBUG, "asking for oid $oid (mode $mode)" )
            if ($debugging);
        if ($error) {
            dolog( LOG_DEBUG, "error for oid $oid (mode $mode)" )
                if ($debugging);
            $request->setError( $request_info, SNMP_ERR_NOSUCHNAME );
            next;
        }

        if ( $mode == MODE_GET ) {
            set_value( $request, $oid );
        }

        if ( $mode == MODE_GETNEXT ) {
            if ( $oid < $lowestOid ) {
                set_value( $request, $lowestOid );
            }
            elsif ( $oid < $highestOid
                ) #request is somewhere in our range, so return first one after it
            {
                my $i        = 0;
                my $oidToUse = undef;

                #linear search of sorted keys array.
                do {
                    $oidToUse = $ks[$i];
                    $i++;

#print STDERR "Comparing $oid to $oidToUse ".ref($oid)." ".ref($oidToUse).
#      " cmp=".NetSNMP::OID::compare($oid, $oidToUse)." cmp2=".($oid <= $oidToUse)."\n";
                    } while ( NetSNMP::OID::compare( $oid, $oidToUse ) > -1
                    and $i <= scalar @ks );

                #got one to return
                if ( defined $oidToUse ) {
                    dolog( LOG_DEBUG, "Next oid to $oid is $oidToUse" )
                        if ($debugging);
                    set_value( $request, $oidToUse );
                }
            }
        }
    }
    dolog( LOG_DEBUG, "finished processing" ) if ($debugging);
}

sub dolog($$) {
    my ( $level, $msg ) = @_;
    syslog( $level, $msg );
    print STDERR $msg . "\n" if ($debugging);
}

# We need to perform a loop here waiting for snmp requests.     We
# also check for new STATUS data.
$SIG{'INT'}  = \&shut_it_down;
$SIG{'QUIT'} = \&shut_it_down;
$SIG{'TERM'} = \&shut_it_down;
$running     = 1;
while ($running) {
    refresh_status($opt{oid});
    $agent->agent_check_and_process(1);    # 1 = block
}
$agent->shutdown();

dolog( LOG_INFO, "agent shutdown" );

__END__
=head1 NAME

    mysql-agent - report mysql statistics via SNMP 
 
=head1 SYNOPSIS
 
    mysql-agent.pl [options]

    -h HOST, --host=HOST      connect to MySQL DB on HOST
    -u USER, --user=USER      use USER as user to connect to mysql
    -p PASS, --password=PASS  use PASS as password to connect to mysql
    -P PORT, --port=PORT      port to connect (default 3306)
    --daemon-pid=FILE         write PID to FILE instead of $default{pid}
    -n, --no-daemon           do not detach and become a daemon
    -m, --master              check master
    -s, --slave               check slave
    -o OID, --oid=OID         registering OID
    -i INT, --refresh=INT     set refresh interval to INT (seconds)
    -?, --help                display this help and exit
    --man                     display program man page
    -v, --verbose             be verbose about what you do
    -V, --version             output version information and exit

=head1 OPTIONS

=over 8

=item B<-h HOST, --host=HOST>

connect to MySQL DB on HOST

=item B<-u USER, --user=USER>

use USER as user to connect to mysql

=item B<-p PASS, --password=PASS>

use PASS as password to connect to mysql

=item B<-P PORT, --port=PORT>

port to connect (default 3306)

=item B<--daemon-pid=FILE>

write PID to FILE instead of $default{pid}

=item B<-n, --no-daemon>

do not detach and become a daemon

=item B<-m, --master>

check master

=item B<-s, --slave>

check slave

=item B<-o OID, --oid=OID>

registering OID

=item B<-i INT, --refresh=INT>

refresh interval in seconds

=item B<-?, --help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<-v, --verbose>

be verbose about what you do

=item B<-V, --version>

output version information and exit

=back

=head1 DESCRIPTION

B<mysql-agent> is a small daemon that connects to a local snmpd daemon
to report statistics on a local or remote MySQL server.

=cut