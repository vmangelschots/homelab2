 talosctl apply-config -f controlplane.yaml -n 192.168.20.11 -e 192.168.20.11 --config-patch @chronos.patch.yaml 
 talosctl apply-config -f controlplane.yaml -n 192.168.20.12 -e 192.168.20.11 --config-patch @metis.patch.yaml 
 talosctl apply-config -f controlplane.yaml -n 192.168.20.13 -e 192.168.20.11 --config-patch @themis.patch.yaml 
 talosctl apply-config -f worker.yaml -n 192.168.20.22 -e 192.168.20.11 --config-patch @argus.patch.yaml --config-patch @intel-workers-patch.yaml 
 talosctl apply-config -f worker.yaml -n 192.168.20.21 -e 192.168.20.11 --config-patch @hercules.patch.yaml --config-patch @intel-workers-patch.yaml 
