
{{- $drydock_url := tuple "physicalprovisioner" "public" "api" . | include "helm-toolkit.endpoints.keystone_endpoint_uri_lookup" }}
{{- if not (empty .Values.conf.drydock.bootaction_url) }}
{{- $drydock_url = .Values.conf.drydock.bootaction_url }}
{{- end }}

#cloud-config
debconf_selections:
 maas: |
  {{ "{{" }}for line in str(curtin_preseed).splitlines(){{ "}}" }}
  {{ "{{" }}line{{ "}}" }}
  {{ "{{" }}endfor{{ "}}" }}
early_commands:
{{ "{{" }}if third_party_drivers and driver{{ "}}" }}
  {{ "{{" }}py: key_string = ''.join(['\\x%x' % x for x in driver['key_binary']]){{ "}}" }}
  {{ "{{" }}if driver['key_binary'] and driver['repository'] and driver['package']{{ "}}" }}
  driver_00_get_key: /bin/echo -en '{{ "{{" }}key_string{{ "}}" }}' > /tmp/maas-{{ "{{" }}driver['package']{{ "}}" }}.gpg
  driver_01_add_key: ["apt-key", "add", "/tmp/maas-{{ "{{" }}driver['package']{{ "}}" }}.gpg"]
  {{ "{{" }}endif{{ "}}" }}
  {{ "{{" }}if driver['repository']{{ "}}" }}
  driver_02_add: ["add-apt-repository", "-y", "deb {{ "{{" }}driver['repository']{{ "}}" }} {{ "{{" }}node.get_distro_series(){{ "}}" }} main"]
  {{ "{{" }}endif{{ "}}" }}
  {{ "{{" }}if driver['package']{{ "}}" }}
  driver_03_update_install: ["sh", "-c", "apt-get update --quiet && apt-get --assume-yes install {{ "{{" }}driver['package']{{ "}}" }}"]
  {{ "{{" }}endif{{ "}}" }}
  {{ "{{" }}if driver['module']{{ "}}" }}
  driver_04_load: ["sh", "-c", "depmod && modprobe {{ "{{" }}driver['module']{{ "}}" }} || echo 'Warning: Failed to load module: {{ "{{" }}driver['module']{{ "}}" }}'"]
  {{ "{{" }}endif{{ "}}" }}
{{ "{{" }}else{{ "}}" }}
  driver_00: ["sh", "-c", "echo third party drivers not installed or necessary."]
{{ "{{" }}endif{{ "}}" }}
late_commands:
{{ "{{" }}py:
def find_ba_key(n):
    tag_prefix = "%s__baid" % n.hostname
    for t in n.tag_names():
        if t.startswith(tag_prefix):
            prefix, ba_key = t.split('__baid__')
            return ba_key
    return False
{{ "}}" }}
{{ "{{" }}py: ba_key = find_ba_key(node){{ "}}" }}
{{ "{{" }}py: ba_units_url = ''.join([{{ quote $drydock_url }},'/bootactions/nodes/',node.hostname,'/units']){{ "}}" }}
{{ "{{" }}py: ba_files_url = ''.join([{{ quote $drydock_url }},'/bootactions/nodes/',node.hostname,'/files']){{ "}}" }}
{{ "{{" }}if ba_key{{ "}}" }}
  drydock_00: ["sh", "-c", "echo Installing Drydock Boot Actions."]
  drydock_01: ["curtin", "in-target", "--", "wget", "--no-proxy", "--no-check-certificate", "--header=X-Bootaction-Key: {{ "{{" }}ba_key{{ "}}" }}", "{{ "{{" }}ba_units_url{{ "}}" }}", "-O", "/tmp/bootaction-units.tar.gz"]
  drydock_02: ["curtin", "in-target", "--", "wget", "--no-proxy", "--no-check-certificate", "--header=X-Bootaction-Key: {{ "{{" }}ba_key{{ "}}" }}", "{{ "{{" }}ba_files_url{{ "}}" }}", "-O", "/tmp/bootaction-files.tar.gz"]
  drydock_03: ["curtin", "in-target", "--", "sh", "-c", "tar --owner=root -xPzvf /tmp/bootaction-units.tar.gz > /tmp/bootaction-unit-names.txt"]
  drydock_04: ["curtin", "in-target", "--", "sh", "-c", "tar --owner=root -xPzvf /tmp/bootaction-files.tar.gz > /tmp/bootaction-file-names.txt"]
  drydock_05: ["curtin", "in-target", "--", "sh", "-c", "xargs -a /tmp/bootaction-unit-names.txt -n 1 basename > /tmp/bootaction-unit-basenames.txt || echo 'Did not run basenames on units'"]
  drydock_06: ["curtin", "in-target", "--", "sh", "-c", "xargs -a /tmp/bootaction-unit-basenames.txt -n 1 systemctl enable || echo 'Did not enable SystemD units'"]
  drydock_07: ["sh", "-c", "echo Following SystemD units installed and enabled:"]
  drydock_08: ["curtin", "in-target", "--", "cat", "/tmp/bootaction-unit-basenames.txt"]
  drydock_09: ["sh", "-c", "echo Following files installed on deployed node:"]
  drydock_10: ["curtin", "in-target", "--", "cat", "/tmp/bootaction-file-names.txt"]
{{ "{{" }}endif{{ "}}" }}
  maas: [wget, '--no-proxy', {{ "{{" }}node_disable_pxe_url|escape.json{{ "}}" }}, '--post-data', {{ "{{" }}node_disable_pxe_data|escape.json{{ "}}" }}, '-O', '/dev/null']
{{ "{{" }}if third_party_drivers and driver{{ "}}" }}
  {{ "{{" }}if driver['key_binary'] and driver['repository'] and driver['package']{{ "}}" }}
  driver_00_key_get: curtin in-target -- sh -c "/bin/echo -en '{{ "{{" }}key_string{{ "}}" }}' > /tmp/maas-{{ "{{" }}driver['package']{{ "}}" }}.gpg"
  driver_02_key_add: ["curtin", "in-target", "--", "apt-key", "add", "/tmp/maas-{{ "{{" }}driver['package']{{ "}}" }}.gpg"]
  {{ "{{" }}endif{{ "}}" }}
  {{ "{{" }}if driver['repository']{{ "}}" }}
  driver_03_add: ["curtin", "in-target", "--", "add-apt-repository", "-y", "deb {{ "{{" }}driver['repository']{{ "}}" }} {{ "{{" }}node.get_distro_series(){{ "}}" }} main"]
  {{ "{{" }}endif{{ "}}" }}
  driver_04_update_install: ["curtin", "in-target", "--", "apt-get", "update", "--quiet"]
  {{ "{{" }}if driver['package']{{ "}}" }}
  driver_05_install: ["curtin", "in-target", "--", "apt-get", "-y", "install", "{{ "{{" }}driver['package']{{ "}}" }}"]
  {{ "{{" }}endif{{ "}}" }}
  driver_06_depmod: ["curtin", "in-target", "--", "depmod"]
  driver_07_update_initramfs: ["curtin", "in-target", "--", "update-initramfs", "-u"]
{{ "{{" }}endif{{ "}}" }}
showtrace: true
swap:
  size: 0
verbosity: 2
{{- if not (empty .Values.conf.maas.system_user) }}
{{- if not (empty .Values.conf.maas.system_passwd) }}
write_files:
  # Create cloud-init config that configures the 'root' user as the
  # default user instead of 'centos'.
  # Additionally, enables password authentication for this user.
  userconfig:
    path: /etc/cloud/cloud.cfg.d/00-user.cfg
    content: |
      ssh_pwauth: yes
      disable_root: false
      system_info:
        default_user:
          name: {{ .Values.conf.maas.system_user | squote }}
          lock_passwd: false
          plain_text_passwd: {{ .Values.conf.maas.system_passwd | squote }}
{{- end }}
{{- end }}
