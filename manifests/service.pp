# == Class zookeeper::service
#
class zookeeper::service inherits zookeeper {

  # See also:
  # http://arch.corp.anjuke.com/blog/2012/08/27/use-supervisord-with-storm-and-zookeeper/
  # https://gist.github.com/solar/3898427

  if !($service_ensure in ['present', 'absent']) {
    fail('service_ensure parameter must be "present" or "absent"')
  }

  if $service_manage == true {

    # Note: ZK actually requires the initialization of both dataDir and dataLogDir.  However the initialization script
    # shipped with ZooKeeper only allows you to initialize both at the same time, and it will fail/exit whenever one
    # (or both) of them are already initialized.  For this reason we do not add any logic that tries to detect which
    # directory exactly is already initialized, and checking only on dataDir (the more important of the two) is
    # sufficient.  Unfortunately, this behavior of ZK means that you will not be easily able to change from a
    # dataDir-only setup to a split dataDir/dataLogDir setup -- doing so requires manual intervention.
    $initialize_check = $is_standalone ? {
      true  => "test ! -d ${data_dir}/version-2",
      false => "test ! -d ${data_dir}/version-2 -o ! -s ${data_dir}/myid",
    }

#    exec { 'zookeeper-initialize':
#      command => 'zookeeper-server start',
#      path    => ['/usr/bin', '/usr/sbin', '/sbin', '/bin'],
#      user    => 'root',
#      onlyif  => $initialize_check,
#      require => [ Class['zookeeper::install'], Class['zookeeper::config'] ],
#    }

    supervisor::service {
      $service_name:
        ensure                 => $service_ensure,
        enable                 => $service_enable,
        command                => $command,
        directory              => '/',
        user                   => $user,
        group                  => $group,
        autorestart            => $service_autorestart,
        startsecs              => $service_startsecs,
        retries                => $service_retries,
        stopsignal             => $service_stopsignal,
        stopasgroup            => $service_stopasgroup,
        stdout_logfile_maxsize => $service_stdout_logfile_maxsize,
        stdout_logfile_keep    => $service_stdout_logfile_keep,
        stderr_logfile_maxsize => $service_stderr_logfile_maxsize,
        stderr_logfile_keep    => $service_stderr_logfile_keep,
        #require                => [ Exec['zookeeper-initialize'], Class['zookeeper::config'], Class['::supervisor'] ],
        require                => [  Class['zookeeper::config'], Class['::supervisor'] ],
    }

    # Make sure that the init.d script shipped with zookeeper-server is not registered as a system service and that the
    # service itself is not running in any case (because we want to run ZooKeeper via supervisord).
#    service { $package_name:
#      ensure => 'stopped',
#      enable => false,
#    }

    $subscribe_real = $is_standalone ? {
      true  => File[$config],
      false => [ File[$config], File['zookeeper-myid'] ],
    }

    if $service_enable == true {
      exec { 'restart-zookeeper':
        command     => "supervisorctl restart ${service_name}",
        path        => ['/usr/bin', '/usr/sbin', '/sbin', '/bin'],
        user        => 'root',
        refreshonly => true,
        subscribe   => $subscribe_real,
        onlyif      => 'which supervisorctl &>/dev/null',
        require     => Class['::supervisor'],
      }
    }

  }

}
