class ManageIQ::Providers::IbmPowerHmc::Inventory::Parser::InfraManager < ManageIQ::Providers::IbmPowerHmc::Inventory::Parser
  def parse
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    collector.collect!

    parse_hosts
    parse_vms
  end

  def parse_hosts
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    collector.hosts.each do |sys|
      host = persister.hosts.build(
        :uid_ems             => sys.uuid,
        :ems_ref             => sys.uuid,
        :name                => sys.name,
        :hypervisor_hostname => "#{sys.mtype}#{sys.model}_#{sys.serial}",
        :hostname            => sys.hostname,
        :ipaddress           => sys.ipaddr,
        :power_state         => lookup_power_state(sys.state)
      )

      parse_host_operating_system(host, sys)
      parse_host_hardware(host, sys)
    end
  end

  def parse_host_operating_system(host, sys)
    persister.host_operating_systems.build(
      :host         => host,
      :product_name => "phyp",
      :build_number => sys.fwversion
    )
  end

  def parse_host_hardware(host, sys)
    hardware = persister.host_hardwares.build(
      :host            => host,
      :cpu_type        => "ppc64",
      :bitness         => 64,
      :manufacturer    => "IBM",
      :model           => "#{sys.mtype}#{sys.model}",
      # :cpu_speed     => 2348, # in MHz
      :memory_mb       => sys.memory,
      :cpu_total_cores => sys.cpus,
      :serial_number   => sys.serial
    )

    parse_host_guest_devices(hardware, sys)
  end

  def parse_host_guest_devices(hardware, sys)
    # persister.host_guest_devices.build(
    #   :hardware    => hardware,
    #   :uid_ems     => sys.xxx,
    #   :device_name => sys.xxx,
    #   :device_type => sys.xxx
    # )
  end

  def parse_vms
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    collector.vms.each do |lpar|
      host = persister.hosts.lazy_find(lpar.sys_uuid)
      vm = persister.vms.build(
        :uid_ems         => lpar.uuid,
        :ems_ref         => lpar.uuid,
        :name            => lpar.name,
        :location        => "unknown",
        :description     => lpar.type,
        :vendor          => "ibm_power_vc", # Damien: add ibm_power_hmc to MIQ
        :raw_power_state => lpar.state,
        :host            => host
        # :connection_state => nil, # Damien: lpar.rmc_state?
        # :ipaddresses      => [lpar.rmc_ipaddr] unless lpar.rmc_ipaddr.nil?
      )

      parse_vm_hardware(vm, lpar)
    end
  end

  def parse_vm_hardware(vm, lpar)
    persister.hardwares.build(
      :vm_or_template => vm,
      :memory_mb      => lpar.memory
    )
  end

  def lookup_power_state(state)
    # See SystemState.Enum (/rest/api/web/schema/inc/Enumerations.xsd)
    case state.downcase
    when /error.*/                    then "off"
    when "failed authentication"      then "off"
    when "incomplete"                 then "off"
    when "initializing"               then "on"
    when "no connection"              then "unknown"
    when "on demand recovery"         then "off"
    when "operating"                  then "on"
    when /pending authentication.*/   then "off"
    when "power off"                  then "off"
    when "power off in progress"      then "off"
    when "recovery"                   then "off"
    when "standby"                    then "off"
    when "version mismatch"           then "on"
    when "service processor failover" then "off"
    when "unknown"                    then "unknown"
    else                                   "off"
    end
  end
end
