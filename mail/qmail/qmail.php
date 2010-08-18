#!/usr/bin/php
<?php


/**
 * Ganglia gmetric script to display local/remote queue message count.
 * 
 * Version 0.1
 * Pablo Godel
 * http://www.godel.com.ar/gmetric_qmail.php
 *
 * Instructions:
 * 1. Download script
 * 2. chmod u+x gmetric_qmail.php
 * 3. run
 */

class Qmail 
{
    protected $queue_path = '/var/qmail/queue';
    
	function countQueue($path)
	{
	    $total = 0;    
	
        foreach( new DirectoryIterator($path) as $qdir) {
            $qdir = $qdir->__toString();
            
            if ( $qdir[0] != '.' )
            {
                foreach( new DirectoryIterator($path.DIRECTORY_SEPARATOR.$qdir) as $file ) {
                    $fname = $file->__toString();
                    if ( $fname[0] != '.') $total++;
                }
                
            }
            
        }
        
        return $total;
			    
	}
	
	public function countRemote()
	{
		$path = $this->queue_path.DIRECTORY_SEPARATOR.'remote';
		$remote = $this->countQueue( $path );

		return $remote;
	}
	
	public function countLocal()
	{
	    
		$path = $this->queue_path.DIRECTORY_SEPARATOR.'local';
		$local = $this->countQueue( $path );
		
		return $local;
	}

}

$q = new Qmail();

$r = $q->countRemote();
$l = $q->countLocal();

exec( "/usr/bin/gmetric --name qmail_remote_queue --value $r --type int16 --units Messages" );
exec( "/usr/bin/gmetric --name qmail_local_queue --value $l --type int16 --units Messages" );