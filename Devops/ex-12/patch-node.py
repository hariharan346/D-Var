import json
import subprocess

# Fetch the current node status directly
fetch_result = subprocess.run(
    ['kubectl', 'get', 'node', 'k3d-ex12-agent-0', '-o', 'json'],
    capture_output=True, text=True
)

if fetch_result.returncode != 0:
    print("Failed to fetch node status:", fetch_result.stderr)
    exit(1)

node = json.loads(fetch_result.stdout)

# Find and update the conditions
for cond in node['status']['conditions']:
    if cond['type'] == 'DiskPressure':
        cond['status'] = 'True'
        cond['reason'] = 'KubeletHasDiskPressure'
        cond['message'] = 'kubelet has disk pressure due to log volume exhaustion'
    elif cond['type'] == 'Ready':
        cond['status'] = 'False'
        cond['reason'] = 'KubeletNotReady'
        cond['message'] = 'kubelet is posting ready status'

# Save the updated node status JSON
with open('node-status.json', 'w') as f:
    json.dump(node, f)

# Apply the status patch to the API server
result = subprocess.run(
    ['kubectl', 'replace', '--raw', '/api/v1/nodes/k3d-ex12-agent-0/status', '-f', 'node-status.json'],
    capture_output=True, text=True
)
print("STDOUT:", result.stdout)
print("STDERR:", result.stderr)
