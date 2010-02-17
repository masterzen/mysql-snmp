#!/usr/bin/perl -w

BEGIN {
    require 'mysql-agent';
}

use Test::More tests => 10;
use Data::Dumper;

sub readfile
{
    my $file = shift;
    my @lines = ();

    open(my $fh, "<", $file);
    while( <$fh> ) {
        chomp($_);
        push @lines, $_ ;
    }
    return \@lines;
}

$innodb_parser = InnoDBParser->new;

is(
   $innodb_parser->make_bigint('0', '1170663853'),
   '1170663853',
   'make_bigint 0 1170663853'
);

is(
   $innodb_parser->make_bigint('1', '504617703'),
   '4799584999',
   'make_bigint 1 504617703'
);

is(
   $innodb_parser->make_bigint('EF861B144C'),
   '1028747105356',
   'make_bigint EF861B144C'
);

is(
   $innodb_parser->tonum('0'),
   '0',
   'tonum 0'
);

is(
   $innodb_parser->tonum(),
   '0',
   'tonum undef'
);

is(
   $innodb_parser->tonum('74900191315') - $innodb_parser->tonum('1170664159'),
   '73729527156',
   'substraction 1170664159 74900191315'
);

is_deeply(
   $innodb_parser->parse_innodb_status(readfile('tests/data/innodb_out_001.txt')),
   {
       'spin_waits'                => '8317256878',
       'spin_rounds'               => '247280272495',
       'os_waits'                  => '1962880678',
       'innodb_transactions'       => '1170664159',
       'unpurged_txns'             => '306',
       'history_list'              => '9',
       'current_transactions'      => '36',
       'pending_normal_aio_reads'  => '0',
       'pending_normal_aio_writes' => '0',
       'pending_ibuf_aio_reads'    => '0',
       'pending_aio_log_ios'       => '0',
       'pending_aio_sync_ios'      => '0',
       'pending_log_flushes'       => '0',
       'pending_buf_pool_flushes'  => '0',
       'file_reads'                => '5985113',
       'file_writes'               => '633045221',
       'file_fsyncs'               => '537534629',
       'ibuf_inserts'              => '19817685',
       'ibuf_merged'               => '19817684',
       'ibuf_merges'               => '3552620',
       'unflushed_log'             => '0',
       'pending_log_writes'        => '0',
       'pending_chkp_writes'       => '0',
       'log_writes'                => '520835887',
       'pool_size'                 => '720896',
       'free_pages'                => '0',
       'database_pages'            => '638423',
       'modified_pages'            => '118',
       'pages_read'                => '28593890',
       'pages_created'             => '5375161',
       'pages_written'             => '154670836',
       'queries_inside'            => '0',
       'queries_queued'            => '0',
       'read_views'                => '1',
       'rows_inserted'             => '544159502',
       'rows_updated'              => '355138902',
       'rows_deleted'              => '50580680',
       'rows_read'                 => '1911833505287',
       'log_bytes_written'         => '540805326864',
       'log_bytes_flushed'         => '540805326864',
       'locked_transactions'       => '0',
       'active_transactions'       => '0',
       'hash_index_cells_total'    => '23374853',
       'hash_index_cells_used'     => '21238151',
       'total_mem_alloc'           => '13102052218',
       'additional_pool_alloc'     => '1048576',
       'last_checkpoint'           => '540805205461',
       'uncheckpointed_bytes'      => '121403',
       'ibuf_used_cells'           => '1',
       'ibuf_free_cells'           => '4634',
       'ibuf_cell_count'           => '4636',
       'adaptive_hash_memory'      => '1538240664',
       'page_hash_memory'          => '11688584',
       'dictionary_cache_memory'   => '145525560',
       'file_system_memory'        => '313848',
       'lock_system_memory'        => '29232616',
       'recovery_system_memory'    => '0',
       'thread_hash_memory'        => '409336',
       'innodb_io_pattern_memory'  => '0',
       'innodb_locked_tables'      => '0',
       'innodb_lock_wait_secs'     => '0',
       'innodb_lock_structs'       => '0',
       'innodb_tables_in_use'      => '0',
   },
   'tests/data/innodb_out_001.txt'
);

is_deeply(
   $innodb_parser->parse_innodb_status(readfile('tests/data/xtradb_01.txt')),
   {
       'spin_waits'                => '271737',
       'spin_rounds'               => '68827',
       'os_waits'                  => '138477',
       'innodb_transactions'       => '8999688',
       'unpurged_txns'             => '7344',
       'history_list'              => '13',
       'current_transactions'      => '1',
       'pending_normal_aio_reads'  => '0',
       'pending_normal_aio_writes' => '0',
       'pending_ibuf_aio_reads'    => '0',
       'pending_aio_log_ios'       => '0',
       'pending_aio_sync_ios'      => '0',
       'pending_log_flushes'       => '0',
       'pending_buf_pool_flushes'  => '0',
       'file_reads'                => '392681',
       'file_writes'               => '1953764',
       'file_fsyncs'               => '870854',
       'ibuf_inserts'              => '220',
       'ibuf_merged'               => '220',
       'ibuf_merges'               => '4055',
       'unflushed_log'             => '0',
       'pending_log_writes'        => '0',
       'pending_chkp_writes'       => '0',
       'log_writes'                => '698593',
       'pool_size'                 => '8191',
       'free_pages'                => '0',
       'database_pages'            => '8102',
       'modified_pages'            => '8',
       'pages_read'                => '437072',
       'pages_created'             => '123813',
       'pages_written'             => '1118512',
       'queries_inside'            => '0',
       'queries_queued'            => '0',
       'read_views'                => '1',
       'rows_inserted'             => '2222849',
       'rows_updated'              => '14659',
       'rows_deleted'              => '15874',
       'rows_read'                 => '8561142',
       'log_bytes_written'         => '65760334407',
       'log_bytes_flushed'         => '65760334407',
       'locked_transactions'       => '0',
       'innodb_lock_structs'       => '0',
       'active_transactions'       => '0',
       'hash_index_cells_total'    => '276671',
       'hash_index_cells_used'     => '0',
       'total_mem_alloc'           => '170487778',
       'additional_pool_alloc'     => '1048576',
       'last_checkpoint'           => '65760333718',
       'uncheckpointed_bytes'      => '689',
       'ibuf_used_cells'           => '1',
       'ibuf_free_cells'           => '2141',
       'ibuf_cell_count'           => '2143',
       'adaptive_hash_memory'      => '3679712',
       'page_hash_memory'          => '139112',
       'dictionary_cache_memory'   => '3773288',
       'file_system_memory'        => '317256',
       'lock_system_memory'        => '333360',
       'recovery_system_memory'    => '0',
       'thread_hash_memory'        => '83176',
       'innodb_locked_tables'      => '0',
       'innodb_lock_wait_secs'     => '0',
       'innodb_tables_in_use'      => '0',
   },
   'tests/data/xtradb_01.txt'
);

is_deeply(
   $innodb_parser->parse_innodb_status(readfile('tests/data/5.0.txt')),
   {
       'spin_waits'                => '22614379',
       'spin_rounds'               => '22315875',
       'os_waits'                  => '973767',
       'innodb_transactions'       => '5067175647',
       'unpurged_txns'             => '475',
       'history_list'              => '141',
       'current_transactions'      => '8',
       'pending_normal_aio_reads'  => '0',
       'pending_normal_aio_writes' => '0',
       'pending_ibuf_aio_reads'    => '0',
       'pending_aio_log_ios'       => '0',
       'pending_aio_sync_ios'      => '0',
       'pending_log_flushes'       => '0',
       'pending_buf_pool_flushes'  => '0',
       'file_reads'                => '272402',
       'file_writes'               => '27233782',
       'file_fsyncs'               => '23274147',
       'ibuf_inserts'              => '32096',
       'ibuf_merged'               => '32096',
       'ibuf_merges'               => '8361',
       'unflushed_log'             => '0',
       'pending_log_writes'        => '0',
       'pending_chkp_writes'       => '0',
       'log_writes'                => '20653125',
       'pool_size'                 => '458752',
       'free_pages'                => '7462',
       'database_pages'            => '349116',
       'modified_pages'            => '659',
       'pages_read'                => '334381',
       'pages_created'             => '16470',
       'pages_written'             => '19427013',
       'queries_inside'            => '0',
       'queries_queued'            => '0',
       'read_views'                => '1',
       'rows_inserted'             => '5329910189',
       'rows_updated'              => '4561332',
       'rows_deleted'              => '1462834',
       'rows_read'                 => '40270926191',
       'log_bytes_written'         => '23751595928144',
       'log_bytes_flushed'         => '23751595928144',
       'locked_transactions'       => '0',
       'active_transactions'       => '0',
       'active_transactions'       => '0',
       'hash_index_cells_total'    => '14874961',
       'hash_index_cells_used'     => '14734156',
       'total_mem_alloc'           => '8288835892',
       'additional_pool_alloc'     => '0',
       'last_checkpoint'           => '23751567838796',
       'uncheckpointed_bytes'      => '28089348',
       'ibuf_used_cells'           => '1',
       'ibuf_free_cells'           => '938',
       'ibuf_cell_count'           => '940',
       'adaptive_hash_memory'      => '1793022712',
       'page_hash_memory'          => '7438328',
       'dictionary_cache_memory'   => '617837272',
       'file_system_memory'        => '254712',
       'lock_system_memory'        => '18597480',
       'recovery_system_memory'    => '0',
       'thread_hash_memory'        => '408056',
       'innodb_io_pattern_memory'  => '0',
       'innodb_locked_tables'      => '0',
       'innodb_lock_wait_secs'     => '0',
       'innodb_lock_structs'       => '0',
       'innodb_tables_in_use'      => '0',
   },
   'tests/data/5.0.txt'
);

is_deeply(
   $innodb_parser->parse_innodb_status(readfile('tests/data/lock.txt')),
   {
       'spin_waits'                => '31',
       'spin_rounds'               => '220',
       'os_waits'                  => '17',
       'innodb_transactions'       => '3411',
       'unpurged_txns'             => '11',
       'history_list'              => '19',
       'current_transactions'      => '2',
       'active_transactions'       => '2',
       'innodb_tables_in_use'      => '1',
       'innodb_locked_tables'      => '1',
       'locked_transactions'       => 1,
       'innodb_lock_structs'       => '9',
       'pending_normal_aio_reads'  => '0',
       'pending_normal_aio_writes' => '0',
       'pending_ibuf_aio_reads'    => '0',
       'pending_aio_log_ios'       => '0',
       'pending_aio_sync_ios'      => '0',
       'pending_log_flushes'       => '0',
       'pending_buf_pool_flushes'  => '0',
       'file_reads'                => '42',
       'file_writes'               => '168',
       'file_fsyncs'               => '149',
       'ibuf_inserts'              => '0',
       'ibuf_merged'               => '0',
       'ibuf_merges'               => '0',
       'log_bytes_written'         => '103216',
       'unflushed_log'             => '0',
       'log_bytes_flushed'         => '103216',
       'pending_log_writes'        => '0',
       'pending_chkp_writes'       => '0',
       'log_writes'                => '72',
       'pool_size'                 => '512',
       'free_pages'                => '476',
       'database_pages'            => '35',
       'modified_pages'            => '0',
       'pages_read'                => '33',
       'pages_created'             => '48',
       'pages_written'             => '148',
       'queries_inside'            => '0',
       'queries_queued'            => '0',
       'read_views'                => '2',
       'rows_inserted'             => '5',
       'rows_updated'              => '0',
       'rows_deleted'              => '0',
       'rows_read'                 => '10',
       'innodb_lock_wait_secs'     => '32',
       'hash_index_cells_total'    => '17393',
       'hash_index_cells_used'     => '0',
       'total_mem_alloc'           => '20557306',
       'additional_pool_alloc'     => '744704',
       'last_checkpoint'           => '103216',
       'uncheckpointed_bytes'      => '0',
       'ibuf_used_cells'           => '1',
       'ibuf_free_cells'           => '0',
       'ibuf_cell_count'           => '2',
   },
   'tests/data/lock.txt'
);
