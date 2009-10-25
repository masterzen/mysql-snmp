#!/usr/bin/perl -w

BEGIN {
    require 'mysql-agent';
}

use Test::More tests => 3;
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
       'active_transactions'       => '0',
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
   },
   'tests/data/5.0.txt'
);
