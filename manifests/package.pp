# == Class: zookeeper::package
# This class exists to coordinate zookeeper package management related actions.
#
# == Authors
#  Leon Cui <mailto: leon.cui@outlook.com>
#

class zookeeper::package {
  Exec {
    path      => [ '/bin', '/usr/bin', '/usr/local/bin' ],
    cwd       => '/',
    tries     => 3,
    try_sleep => 10
  }

  #### Package management

  if $zookeeper::package_ensure == 'present' {
    # Check if we want to install a specific version or not
    if $zookeeper::version == false {

      $package_ensure = $zookeeper::autoupgrade ? {
        true  => 'latest',
        false => 'present',
      }

    } else {

      # install specific version
      $package_ensure = $zookeeper::version

    }

    # action
    if ($zookeeper::package_url != undef) {

      case $zookeeper::package_provider {
        'package': { $before = Package[$zookeeper::package_name]  }
        default:   { fail("software provider \"${zookeeper::software_provider}\".") }
      }

      $package_dir = $zookeeper::package_dir

      # Create directory to place the package file
      exec { 'create_package_dir_zookeeper':
        cwd     => '/',
        path    => ['/usr/bin', '/bin'],
        command => "mkdir -p ${zookeeper::package_dir}",
        creates => $zookeeper::package_dir;
      }

      file { $package_dir:
        ensure  => 'directory',
        purge   => $zookeeper::purge_package_dir,
        force   => $zookeeper::purge_package_dir,
        backup  => false,
        require => Exec['create_package_dir_zookeeper'],
      }

      $filenameArray = split($zookeeper::package_url, '/')
      $basefilename = $filenameArray[-1]

      $sourceArray = split($zookeeper::package_url, ':')
      $protocol_type = $sourceArray[0]

      $extArray = split($basefilename, '\.')
      $ext = $extArray[-1]

      $pkg_source = "${package_dir}/${basefilename}"

      case $protocol_type {

        puppet: {

          file { $pkg_source:
            ensure  => present,
            source  => $zookeeper::package_url,
            require => File[$package_dir],
            backup  => false,
            before  => $before
          }

        }
        ftp, https, http: {

          exec { 'download_package_zookeeper':
            command => "${zookeeper::params::download_tool} ${pkg_source} ${zookeeper::package_url} 2> /dev/null",
            creates => $pkg_source,
            timeout => $zookeeper::package_dl_timeout,
            require => File[$package_dir],
            before  => $before
          }

        }
        file: {

          $source_path = $sourceArray[1]
          file { $pkg_source:
            ensure  => present,
            source  => $source_path,
            require => File[$package_dir],
            backup  => false,
            before  => $before
          }

        }
        default: {
          fail("Protocol must be puppet, file, http, https, or ftp. You have given \"${protocol_type}\"")
        }
      }

      if ($zookeeper::package_provider == 'package') {

        case $ext {
          'deb':   { $pkg_provider = 'dpkg' }
          'rpm':   { $pkg_provider = 'rpm'  }
          default: { fail("Unknown file extention \"${ext}\".") }
        }

      }

    } else {
      $pkg_source = undef
      $pkg_provider = undef
    }

  # Package removal
  } else {

    $pkg_source = undef
    if ($::operatingsystem == 'OpenSuSE') {
      $pkg_provider = 'rpm'
    } else {
      $pkg_provider = undef
    }
    $package_ensure = 'absent'

    $package_dir = $zookeeper::package_dir

    file { $package_dir:
      ensure => 'absent',
      purge  => true,
      force  => true,
      backup => false
    }

  }

  if ($zookeeper::package_provider == 'package') {

    package { $zookeeper::package_name:
      ensure            => $package_ensure,
      source            => $pkg_source,
      provider          => $pkg_provider,
    }

  } else {
    fail("\"${zookeeper::package_provider}\" is not supported")
  }
}
