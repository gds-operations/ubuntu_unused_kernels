require "ubuntu_unused_kernels/version"
require "open3"

module UbuntuUnusedKernels
  DPKG_PATTERN = %w{linux-image-* linux-headers-*}
  VERSION_REGEX = %r{\d+\.\d+\.\d+-\d+}

  class << self
    def to_remove
      current = get_current
      packages = get_installed

      latest = packages.map { |package|
        package.match(VERSION_REGEX)[0]
      }.uniq.sort.last(2)

      [current, latest].flatten.each { |version|
        packages.reject! { |package|
          package =~ /\b#{Regexp.escape(version)}\b/
        }
      }

      return packages
    end

    def get_current
      uname = Open3.capture2('uname', '-r')
      raise "Unable to determine current kernel" unless uname.last.success?

      match = uname.first.chomp.match(/^(#{VERSION_REGEX})-[[:alpha:]]+$/)
      raise "Unable to determine current kernel" unless match

      return match[1]
    end

    def get_installed
      dpkg = Open3.capture2(
        'dpkg-query', '--show',
        '--showformat', '${Package}\t${Version}\n',
        *DPKG_PATTERN
      )
      raise "Unable to get list of packages" unless dpkg.last.success?

      packages = dpkg.first.split("\n")
      packages.map! { |p| p.split("\t") }
      packages.reject! { |p| p[1].nil? }
      packages.map! { |p| p[0] }
      packages.reject! { |p| p !~ VERSION_REGEX }
      raise "No kernel packages found" if packages.empty?

      return packages
    end
  end
end
