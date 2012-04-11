<?php

/* Sample report template */

/* Instructions for adding custom reports

1) Reports should have a primary function named:  "<yourtesthere>_report".  This 
   fuction will be called from the graph.php script automatically.

2) The *_report script should return an array that contains at least the variables
   listed below.  Several have been pre-populated, and may not need to be changed.
   However, you will have to alter at least these:  $series, $title, $vertical_label
   
3) An array variable is passed to the function in order to make sure that certain 
   variables are available for use.  This is PASSED BY REFERENCE and CAN BE CHANGED
   by your report function.
   
   

A full list of variables that will be used:

    $series          (string: holds the meat of the rrdgraph definition)
    $title           (string: title of the report)
    $vertical_label  (label for Y-Axis.)

    $start           (String: Start time of the graph, can usually be left alone)
    $end             (String: End time of the graph, also can usually be left alone)

    $width           (Strings:  Width and height of *graph*, the actual image will be 
    $height           slightly larger due to text elements and padding.  These
                      are normally set automatically, depending on the graph size
                      chosen from the web UI)

    $upper-limit     (Strings: Maximum and minimum Y-value for the graph.  RRDTool
    $lower-limit      normally will auto-scale the Y min and max to fit the
                      data.  You may override this by setting these variables
                      to specific limits.  The default value is a null string,
                      which will force the auto-scale behavior)
    
    $color           (ARRAY:  Sets one or more chart colors.  Usually used for setting
                      the background color of the chart.  Valid array keys are
                      BACK, CANVAS, SADEA, SHADEB, FONT, FRAME and ARROW.  Usually,
                      only BACK is set).
    
    $extras          (Any other custom rrdtool commands can be added to this
                      this variable.  For example, setting a different --base
                      value or use a --logarithmic scale)
        
                    
For more information and specifics, see the man page for 'rrdgraph'.                      
   


*/

function graph_jobqueue_report ( &$rrdtool_graph ) {

/* this is just the cpu_report (from revision r920) as an example, but with extra comments */

    // pull in a number of global variables, many set in conf.php (such as colors and $rrd_dir),
    // but other from elsewhere, such as get_context.php

    global $context, 
           $fudge_2,
           $cpu_idle_color,
           $cpu_nice_color, 
           $cpu_system_color, 
           $cpu_user_color,
           $cpu_wio_color,
           $hostname,
           $rrd_dir,
           $size,
           $use_fqdn_hostname;

    if (!$use_fqdn_hostname) {
        $hostname = strip_domainname($hostname);
    }

    //
    // You *MUST* set at least the 'title', 'vertical-label', and 'series' variables.
    //
    $rrdtool_graph['title']          = 'Job queues';    // This will be turned into:   "Clustername $TITLE last $timerange", so keep it short
    $rrdtool_graph['vertical-label'] = 'Jobs';
    $rrdtool_graph['height']        += $size == 'medium' ? 28 : 0 ;   // Fudge to account for number of lines in the chart legend
    $rrdtool_graph['lower-limit']    = '.5';
    $rrdtool_graph['extras']         = '--logarithmic --units=si -X 0 --rigid';

    $core_title = $size == 'large' ? 'Total CPU cores' : 'Cores';


    $series =
        "DEF:'r_running'='${rrd_dir}/sge_running.rrd':'sum':AVERAGE "
       ."DEF:'r_errors'='${rrd_dir}/sge_error.rrd':'sum':AVERAGE "
       ."DEF:'r_pending'='${rrd_dir}/sge_pending.rrd':'sum':AVERAGE "
       ."DEF:'cores'='${rrd_dir}/cpu_num.rrd':'sum':AVERAGE "
       ."VDEF:l_running=r_running,LAST "
       ."VDEF:l_pending=r_pending,LAST "
       ."VDEF:l_errors=r_errors,LAST "
       ."VDEF:l_cores=cores,LAST "
       ."CDEF:c_errors=r_errors,0,EQ,UNKN,r_errors,IF "
       ."CDEF:c_running=r_running,0,EQ,UNKN,r_running,IF "
       ."CDEF:c_pending=r_pending,0,EQ,UNKN,r_pending,IF "
       ."LINE3:'cores'#FF7F50:'$core_title\g' "
       ."GPRINT:l_cores:'(%.0lf)' "
       ."LINE2:'c_running'#33cc00:'Running\g' "
       ."GPRINT:l_running:'(%.0lf)' "
       ."LINE2:'c_pending'#0033CC:'Pending\g' "
       ."GPRINT:l_pending:'(%.0lf)' "
       ."LINE3:'c_errors'#CC0000:'Errors\g' "
       ."GPRINT:l_errors:'(%.0lf)\l' "
       ;


    $rrdtool_graph['series'] = $series;

    return $rrdtool_graph;
}

?>
