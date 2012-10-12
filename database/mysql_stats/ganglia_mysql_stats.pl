#!/usr/bin/perl -W

###########################################################################
# Author: Vladimir Vuksan http://vuksan.com/linux/
# License: GNU Public License (http://www.gnu.org/copyleft/gpl.html)
# Collects mySQL 5.5+ server metrics. 
# Inspired by Ben Hartshorne's mySQL gmetric script http://ben.hartshorne.net/ganglia/
###########################################################################

# NEED TO MODIFY FOLLOWING
# Adjust this variables appropriately. Feel free to add any options to gmetric_command
# necessary for running gmetric in your environment to gmetric_options e.g. -c /etc/gmond.conf
my $gmetric_exec = "/usr/bin/gmetric";
my $gmetric_options = "";

# You only need to grant usage privilege to the user getting the stats e.g.
#### grant USAGE on *.* to 'ganglia'@'localhost' identified by 'xxxxx';
my $stats_command = "/usr/bin/mysqladmin -u ganglia --password=xxxxx extended-status";

my $metric_prefix = "mysql";

# YOU COULD MODIFY FOLLOWING
# To find out a list of all metrics please do mysqladmin extended-status
# MySQL keeps two types of metrics. Counters e.g. ones that keep increasing
# and absolute metrics ie. number of connections right now. For counters 
# we need to calculate rate ie. delta between timeA and timeB divided by time.
# If you need other metrics add them to either of the two hashes and specify
# the units e.g. bytes, connections, etc.
# Explanation what these metrics means can be found at
# http://dev.mysql.com/doc/refman/5.0/en/server-status-variables.html
my %counter_metrics = (
	"Aborted_clients" => "clients",
	"Aborted_connects" => "conn",
	"Binlog_cache_disk_use" => "trans",
	"Binlog_cache_use" => "trans",
	"Bytes_received" => "bytes",
	"Bytes_sent" => "bytes",
	"Com_admin_commands" => "cmds",
	"Com_assign_to_keycache" => "ops",
	"Com_alter_db" => "ops",
	"Com_alter_db_upgrade" => "ops",
	"Com_alter_event" => "ops",
	"Com_alter_function" => "ops",
	"Com_alter_procedure" => "ops",
	"Com_alter_server" => "ops",
	"Com_alter_table" => "ops",
	"Com_alter_tablespace" => "ops",
	"Com_analyze" => "ops",
	"Com_begin" => "ops",
	"Com_binlog" => "ops",
	"Com_call_procedure" => "ops",
	"Com_change_db" => "ops",
	"Com_change_master" => "ops",
	"Com_check" => "ops",
	"Com_checksum" => "ops",
	"Com_commit" => "ops",
	"Com_create_db" => "ops",
	"Com_create_event" => "ops",
	"Com_create_function" => "ops",
	"Com_create_index" => "ops",
	"Com_create_procedure" => "ops",
	"Com_create_server" => "ops",
	"Com_create_table" => "ops",
	"Com_create_trigger" => "ops",
	"Com_create_udf" => "ops",
	"Com_create_user" => "ops",
	"Com_create_view" => "ops",
	"Com_dealloc_sql" => "ops",
	"Com_delete" => "ops",
	"Com_delete_multi" => "ops",
	"Com_do" => "ops",
	"Com_drop_db" => "ops",
	"Com_drop_event" => "ops",
	"Com_drop_function" => "ops",
	"Com_drop_index" => "ops",
	"Com_drop_procedure" => "ops",
	"Com_drop_server" => "ops",
	"Com_drop_table" => "ops",
	"Com_drop_trigger" => "ops",
	"Com_drop_user" => "ops",
	"Com_drop_view" => "ops",
	"Com_empty_query" => "ops",
	"Com_execute_sql" => "ops",
	"Com_flush" => "ops",
	"Com_grant" => "ops",
	"Com_ha_close" => "ops",
	"Com_ha_open" => "ops",
	"Com_ha_read" => "ops",
	"Com_help" => "ops",
	"Com_insert" => "ops",
	"Com_insert_select" => "ops",
	"Com_install_plugin" => "ops",
	"Com_kill" => "ops",
	"Com_load" => "ops",
	"Com_lock_tables" => "ops",
	"Com_optimize" => "ops",
	"Com_preload_keys" => "ops",
	"Com_prepare_sql" => "ops",
	"Com_purge" => "ops",
	"Com_purge_before_date" => "ops",
	"Com_release_savepoint" => "",
	"Com_rename_table" => "ops",
	"Com_rename_user" => "ops",
	"Com_repair" => "ops",
	"Com_replace" => "ops",
	"Com_replace_select" => "ops",
	"Com_reset" => "ops",
	"Com_resignal" => "ops",
	"Com_revoke" => "ops",
	"Com_revoke_all" => "ops",
	"Com_rollback" => "ops",
	"Com_rollback_to_savepoint" => "ops",
	"Com_savepoint" => "ops",
	"Com_select" => "ops",
	"Com_set_option" => "ops",
	"Com_signal" => "ops",
	"Com_show_authors" => "ops",
	"Com_show_binlog_events" => "ops",
	"Com_show_binlogs" => "ops",
	"Com_show_charsets" => "ops",
	"Com_show_client_statistics" => "ops",
	"Com_show_collations" => "ops",
	"Com_show_contributors" => "ops",
	"Com_show_create_db" => "ops",
	"Com_show_create_event" => "ops",
	"Com_show_create_func" => "ops",
	"Com_show_create_proc" => "ops",
	"Com_show_create_table" => "ops",
	"Com_show_create_trigger" => "ops",
	"Com_show_databases" => "ops",
	"Com_show_engine_logs" => "ops",
	"Com_show_engine_mutex" => "ops",
	"Com_show_engine_status" => "ops",
	"Com_show_events" => "ops",
	"Com_show_errors" => "ops",
	"Com_show_fields" => "ops",
	"Com_show_function_status" => "ops",
	"Com_show_grants" => "ops",
	"Com_show_index_statistics" => "ops",
	"Com_show_keys" => "ops",
	"Com_show_master_status" => "ops",
	"Com_show_open_tables" => "ops",
	"Com_show_plugins" => "ops",
	"Com_show_privileges" => "ops",
	"Com_show_procedure_status" => "ops",
	"Com_show_processlist" => "ops",
	"Com_show_profile" => "ops",
	"Com_show_profiles" => "ops",
	"Com_show_relaylog_events" => "ops",
	"Com_show_slave_hosts" => "ops",
	"Com_show_slave_status" => "ops",
	"Com_show_slave_status_nolock" => "ops",
	"Com_show_status" => "ops",
	"Com_show_storage_engines" => "ops",
	"Com_show_table_statistics" => "ops",
	"Com_show_table_status" => "ops",
	"Com_show_tables" => "ops",
	"Com_show_temporary_tables" => "ops",
	"Com_show_thread_statistics" => "ops",
	"Com_show_triggers" => "ops",
	"Com_show_user_statistics" => "ops",
	"Com_show_variables" => "ops",
	"Com_show_warnings" => "ops",
	"Com_slave_start" => "ops",
	"Com_slave_stop" => "ops",
	"Com_stmt_close" => "ops",
	"Com_stmt_execute" => "ops",
	"Com_stmt_fetch" => "ops",
	"Com_stmt_prepare" => "ops",
	"Com_stmt_reprepare" => "ops",
	"Com_stmt_reset" => "ops",
	"Com_stmt_send_long_data" => "ops",
	"Com_truncate" => "ops",
	"Com_uninstall_plugin" => "ops",
	"Com_unlock_tables" => "ops",
	"Com_update" => "ops",
	"Com_update_multi" => "ops",
	"Com_xa_commit" => "ops",
	"Com_xa_end" => "ops",
	"Com_xa_prepare" => "ops",
	"Com_xa_recover" => "ops",
	"Com_xa_rollback" => "ops",
	"Com_xa_start" => "ops",
	"Connections" => "conn",
	"Created_tmp_disk_tables" => "ops",
	"Created_tmp_files" => "ops",
	"Created_tmp_tables" => "ops",
	"Delayed_errors" => "errs",
	"Delayed_writes" => "writes",
	"Flush_commands" => "flushes",
	"Handler_commit" => "ops",
	"Handler_delete" => "ops",
	"Handler_discover" => "ops",
	"Handler_prepare" => "ops",
	"Handler_read_first" => "ops",
	"Handler_read_key" => "ops",
	"Handler_read_last" => "ops",
	"Handler_read_next" => "ops",
	"Handler_read_prev" => "ops",
	"Handler_read_rnd" => "ops",
	"Handler_read_rnd_next" => "ops",
	"Handler_rollback" => "ops",
	"Handler_savepoint" => "ops",
	"Handler_savepoint_rollback" => "ops",
	"Handler_update" => "updates",
	"Handler_write" => "writes",
	"Innodb_adaptive_hash_cells" => "",
	"Innodb_adaptive_hash_heap_buffers" => "",
	"Innodb_adaptive_hash_hash_searches" => "",
	"Innodb_adaptive_hash_non_hash_searches" => "",
	"Innodb_background_log_sync" => "",
	"Innodb_buffer_pool_pages_flushed" => "reqs",
	"Innodb_buffer_pool_pages_LRU_flushed" => "reqs",
	"Innodb_buffer_pool_read_ahead_rnd" => "",
	"Innodb_buffer_pool_read_ahead" => "",
	"Innodb_buffer_pool_read_ahead_evicted" => "",
	"Innodb_buffer_pool_read_requests" => "",
	"Innodb_buffer_pool_reads" => "",
	"Innodb_buffer_pool_wait_free" => "",
	"Innodb_buffer_pool_write_requests" => "",
	"Innodb_data_fsyncs" => "",
	"Innodb_data_pending_fsyncs" => "",
	"Innodb_data_pending_reads" => "",
	"Innodb_data_pending_writes" => "",
	"Innodb_data_read" => "",
	"Innodb_data_reads" => "",
	"Innodb_data_writes" => "",
	"Innodb_data_written" => "",
	"Innodb_dblwr_pages_written" => "",
	"Innodb_dblwr_writes" => "",
	"Innodb_deadlocks" => "deadlocks",
	"Innodb_dict_tables" => "",
	"Innodb_history_list_length" => "",
	"Innodb_ibuf_discarded_delete_marks" => "del",
	"Innodb_ibuf_discarded_deletes" => "del",
	"Innodb_ibuf_discarded_inserts" => "ins",
	"Innodb_ibuf_free_list" => "",
	"Innodb_ibuf_merged_delete_marks" => "",
	"Innodb_ibuf_merged_deletes" => "",
	"Innodb_ibuf_merged_inserts" => "",
	"Innodb_ibuf_merges" => "",
	"Innodb_log_waits" => "",
	"Innodb_log_write_requests" => "",
	"Innodb_log_writes" => "",
	"Innodb_lsn_current" => "",
	"Innodb_lsn_flushed" => "",
	"Innodb_lsn_last_checkpoint" => "",
	"Innodb_master_thread_1_second_loops" => "",
	"Innodb_master_thread_10_second_loops" => "",
	"Innodb_master_thread_background_loops" => "",
	"Innodb_master_thread_main_flush_loops" => "",
	"Innodb_master_thread_sleeps" => "",
	"Innodb_max_trx_id" => "",
	"Innodb_mutex_os_waits" => "",
	"Innodb_mutex_spin_rounds" => "",
	"Innodb_mutex_spin_waits" => "",
	"Innodb_oldest_view_low_limit_trx_id" => "",
	"Innodb_os_log_fsyncs" => "",
	"Innodb_os_log_written" => "",
	"Innodb_pages_created" => "",
	"Innodb_pages_read" => "",
	"Innodb_pages_written" => "",
	"Innodb_purge_trx_id" => "",
	"Innodb_purge_undo_no" => "",
	"Innodb_row_lock_time" => "",
	"Innodb_row_lock_waits" => "",
	"Innodb_rows_deleted" => "",
	"Innodb_rows_inserted" => "",
	"Innodb_rows_read" => "",
	"Innodb_rows_updated" => "",
	"Innodb_s_lock_os_waits" => "",
	"Innodb_s_lock_spin_rounds" => "",
	"Innodb_s_lock_spin_waits" => "",
	"Innodb_truncated_status_writes" => "",
	"Innodb_x_lock_os_waits" => "",
	"Innodb_x_lock_spin_rounds" => "",
	"Innodb_x_lock_spin_waits" => "",
	"Key_read_requests" => "reqs",
	"Key_reads" => "reads",
	"Key_write_requests" => "reqs",
	"Key_writes" => "writes",
	"Opened_files" => "files",
	"Opened_table_definitions" => "definitions",
	"Opened_tables" => "tables",
	"Performance_schema_cond_classes_lost" => "",
	"Performance_schema_cond_instances_lost" => "",
	"Performance_schema_file_classes_lost" => "",
	"Performance_schema_file_handles_lost" => "",
	"Performance_schema_file_instances_lost" => "",
	"Performance_schema_locker_lost" => "",
	"Performance_schema_mutex_classes_lost" => "",
	"Performance_schema_mutex_instances_lost" => "",
	"Performance_schema_rwlock_classes_lost" => "",
	"Performance_schema_rwlock_instances_lost" => "",
	"Performance_schema_table_handles_lost" => "",
	"Performance_schema_table_instances_lost" => "",
	"Performance_schema_thread_classes_lost" => "",
	"Performance_schema_thread_instances_lost" => "",
	"Prepared_stmt_count" => "stmts",
	"Qcache_hits" => "hits",
	"Qcache_inserts" => "inserts",
	"Qcache_lowmem_prunes" => "ops",
	"Qcache_not_cached" => "ops",
	"Queries" => "q",
	"Select_full_join" => "ops",
	"Select_full_range_join" => "ops",
	"Select_range" => "ops",
	"Select_range_check" => "checks",
	"Select_scan" => "scans",
	"Slave_open_temp_tables" => "",
	"Slave_received_heartbeats" => "",
	"Slave_retried_transactions" => "",
	"Slow_launch_threads" => "threads",
	"Slow_queries" => "queries",
	"Sort_merge_passes" => "passes",
	"Sort_range" => "sorts",
	"Sort_rows" => "rows",
	"Sort_scan" => "scans",
	"Table_locks_immediate" => "locks",
	"Table_locks_waited" => "locks",
	"Tc_log_page_waits" => "waits",
	"Threads_created" => "threads",
	"binlog_commits" => "commits",
	"binlog_group_commits" => "commits"
	);

my %absolute_metrics = (
	"Delayed_insert_threads" => "threads",
	"Innodb_buffer_pool_pages_data" => "pages",
	"Innodb_buffer_pool_pages_dirty" => "pages",
	"Innodb_buffer_pool_pages_free" => "pages",
	"Innodb_buffer_pool_pages_made_not_young" => "pages",
	"Innodb_buffer_pool_pages_made_young" => "pages",
	"Innodb_buffer_pool_pages_misc" => "pages",
	"Innodb_buffer_pool_pages_old" => "pages",
	"Innodb_buffer_pool_pages_total" => "pages",
	"Innodb_checkpoint_age" => "",
	"Innodb_checkpoint_max_age" => "",
	"Innodb_checkpoint_target_age" => "",
	"Innodb_current_row_locks" => "",
	"Innodb_ibuf_segment_size" => "",
	"Innodb_ibuf_size" => "",
	"Innodb_mem_adaptive_hash" => "",
	"Innodb_mem_dictionary" => "",
	"Innodb_mem_total" => "bytes",
	"Innodb_os_log_pending_fsyncs" => "",
	"Innodb_os_log_pending_writes" => "",
	"Innodb_page_size" => "",
	"Innodb_row_lock_current_waits" => "locks",
	"Innodb_row_lock_time_avg" => "sec",
	"Innodb_row_lock_time_max" => "sec",
	"Key_blocks_not_flushed" => "blocks",
	"Key_blocks_unused" => "blocks",
	"Key_blocks_used" => "blocks",
	"Max_used_connections" => "conn",
	"Not_flushed_delayed_rows" => "rows",
	"Open_files" => "files",
	"Open_streams" => "streams",
	"Open_table_definitions" => "definitions",
	"Open_tables" => "tables",
	"Qcache_free_blocks" => "blks",
	"Qcache_free_memory" => "bytes",
	"Qcache_queries_in_cache" => "queries",
	"Qcache_free_memory" => "bytes",
	"Qcache_total_blocks" => "blks",
	"Slave_heartbeat_period" => "",
	"Tc_log_max_pages_used" => "pages",
	"Tc_log_page_size" => "bytes",
	"Threads_cached" => "threads",
        "Threads_connected" => "threads",
	"Threads_running" => "threads" ,
	"Uptime" => "sec",
	"Uptime_since_flush_status" => "sec"
);

# DON"T TOUCH BELOW UNLESS YOU KNOW WHAT YOU ARE DOING
if ( ! -x $gmetric_exec ) {
	die("Gmetric binary is not executable. Exiting...");
}

my $gmetric_command = $gmetric_exec . " " . $gmetric_options;

# Where to store the last stats file
my $tmp_dir_base="/tmp/mysqld_stats";
my $tmp_stats_file=$tmp_dir_base . "/" . "mysqld_stats";

# If the tmp directory doesn't exit create it
if ( ! -d $tmp_dir_base ) {
	system("mkdir -p $tmp_dir_base");
}

my %old_stats, %new_stats;

###############################################################################
# We need to store a baseline with statistics. If it's not there let's dump 
# it into a file. Don't do anything else
###############################################################################
if ( ! -f $tmp_stats_file ) {
	print "Creating baseline. No output this cycle\n";
	system("$stats_command > $tmp_stats_file");
} else {

	######################################################
	# Let's read in the file from the last poll
	open(OLDSTATUS, "< $tmp_stats_file");
	
	while(<OLDSTATUS>)
	{
		if (/\s+(\S+)\s+\S+\s+(\S+)/) {
			$old_stats{$1}=${2};
		}	
	}
	
	# Get the time stamp when the stats file was last modified
	$old_time = (stat $tmp_stats_file)[9];
	close(OLDSTATUS);

	#####################################################
	# Get the new stats
	#####################################################
	system("$stats_command > $tmp_stats_file");
	open(NEWSTATUS, "< $tmp_stats_file");
	my $new_time = time(); 
	
	while(<NEWSTATUS>)
	{
		if (/\s+(\S+)\s+\S+\s+(\S+)/) {
			$new_stats{$1}=${2};
		}
	}
	close(NEWSTATUS);

	# Time difference between this poll and the last poll
	my $time_difference = $new_time - $old_time;
	if ( $time_difference < 1 ) {
		die("Time difference can't be less than 1");
	}
	
	#################################################################################
	# Calculate deltas for counter metrics and send them to ganglia
	#################################################################################	
	while ( my ($metric, $units) = each(%counter_metrics) ) {
	   if ( exists $new_stats{$metric} ) {
		my $rate = ($new_stats{$metric} - $old_stats{$metric}) / $time_difference;

		if ( $rate < 0 ) {
			print "Something is fishy. Rate for " . $metric . " shouldn't be negative. Perhaps counters were reset. Doing nothing";
		} else {
			print "$metric = $rate / sec\n";
			system($gmetric_command . " -u '$units/sec' -tfloat -n ${metric_prefix}_" . lc($metric) . " -v " . $rate);
			
		}
	   }
	}
	
	#################################################################################
	# Just send absolute metrics. No need to calculate delta
	#################################################################################
	while ( my ($metric, $units) = each(%absolute_metrics) ) {
	  if ( exists $new_stats{$metric} ) {
	    print "$metric = $new_stats{$metric}\n";
	    if (  $new_stats{$metric} >= 0 ) {
		system($gmetric_command . " -u $units -tfloat -n ${metric_prefix}_" . lc($metric) . " -v " . $new_stats{$metric});
	    }
	  }
	}

	
	if ( exists $new_stats{"Threads_created"} and exists $new_stats{"Connections"}  ) {
	
	  my $thread_cache_miss_rate = 100 * ( $new_stats{"Threads_created"} / $new_stats{"Connections"} );
	  if ( $thread_cache_miss_rate  >= 0 ) {
	      system($gmetric_command . " -u pct -tfloat -n ${metric_prefix}_thread_cache_miss_rate -v " . $thread_cache_miss_rate);
	  }

	}
	
}
