# Command Reference

All commands available in the AWS EKS cluster management image. For workflow
guides showing how these commands fit together, see the [README](README.md).


## Routers

These scripts dispatch to sub-commands based on the first argument. Run any
router without arguments to see its available sub-commands.

| Script             | Description                                                      |
|--------------------|------------------------------------------------------------------|
| `cluster`          | Top-level router, delegates to `cluster-<verb>` scripts          |
| `cluster-create`   | Create router, delegates to `cluster-create-<noun>` scripts      |
| `cluster-delete`   | Delete router, delegates to `cluster-delete-<noun>` scripts      |
| `cluster-list`     | List router, delegates to `cluster-list-<noun>` scripts          |
| `cluster-upgrade`  | Upgrade router, delegates to `cluster-upgrade-<noun>` scripts    |
| `cluster-cordon`   | Cordon router, delegates to `cluster-cordon-<noun>` scripts      |
| `cluster-uncordon` | Uncordon router, delegates to `cluster-uncordon-<noun>` scripts  |
| `cluster-drain`    | Drain router, delegates to `cluster-drain-<noun>` scripts        |
| `cluster-locksize` | Locksize router, delegates to `cluster-locksize-<noun>` scripts  |
| `cluster-set`      | Set router, delegates to `cluster-set-<noun>` scripts            |
| `cluster-describe` | Describe router, delegates to `cluster-describe-<noun>` scripts  |
| `cluster-document` | Document router, delegates to `cluster-document-<noun>` scripts  |


## Cluster Lifecycle

### create

| Command                                       | Description                                                                |
|-----------------------------------------------|----------------------------------------------------------------------------|
| `cluster create cluster [--dry-run]`          | Create an EKS cluster using eksctl                                         |
| `cluster create nodegroup <name> [--dry-run]` | Create a single EKS nodegroup from cluster.yaml                            |
| `cluster create nodegroups [--dry-run]`       | Create all EKS nodegroups defined in cluster.yaml                          |
| `cluster create addons [--force]`             | Create all EKS addons defined in cluster.yaml                              |
| `cluster bootstrap-cilium`                    | Bootstrap Cilium CNI on a newly created EKS cluster. Not yet implemented.  |

### delete

| Command                           | Description                                          |
|-----------------------------------|------------------------------------------------------|
| `cluster delete cluster`          | Delete an EKS cluster with interactive confirmation  |
| `cluster delete nodegroup <name>` | Delete an EKS nodegroup                              |
| `cluster delete old-nodegroups`   | Delete all nodegroups not defined in cluster.yaml    |
| `cluster delete addon <name>`     | Delete an EKS addon                                  |


## Information

### list

| Command                                   | Description                                                                |
|-------------------------------------------|----------------------------------------------------------------------------|
| `cluster list all`                        | List everything: clusters, version, nodegroups, addons, nodes, and stacks  |
| `cluster list clusters`                   | List EKS clusters                                                          |
| `cluster list version`                    | Show current EKS control plane version and compare with cluster.yaml       |
| `cluster list nodegroups`                 | List EKS nodegroups                                                        |
| `cluster list nodes`                      | List Kubernetes nodes                                                      |
| `cluster list addons`                     | List EKS addons                                                            |
| `cluster list stacks`                     | List CloudFormation stacks managed by eksctl                               |
| `cluster list addon-versions`             | List available addon versions and compatible Kubernetes versions           |
| `cluster list nodegroup-size <name>`      | Show the min, max, and desired size of a nodegroup                         |
| `cluster list nodes-for-nodegroup <name>` | List nodes belonging to a specific nodegroup                               |
| `cluster list nodes-for-new-nodegroups`   | List nodes in nodegroups defined in cluster.yaml                           |
| `cluster list nodes-for-old-nodegroups`   | List nodes in nodegroups not defined in cluster.yaml                       |
| `cluster list old-nodes-not-cordoned`     | List nodes in old nodegroups that are not yet cordoned                     |

### describe

| Command                   | Description                                       |
|---------------------------|---------------------------------------------------|
| `cluster describe stacks` | Describe CloudFormation stacks managed by eksctl  |

### document

| Command                        | Description                        |
|--------------------------------|------------------------------------|
| `cluster document creation`    | Display cluster creation guide     |
| `cluster document maintenance` | Display cluster maintenance guide  |
| `cluster document deletion`    | Display cluster deletion guide     |


## Maintenance

### upgrade

| Command                                     | Description                                          |
|---------------------------------------------|------------------------------------------------------|
| `cluster upgrade controlplane`              | Upgrade the EKS control plane to match cluster.yaml  |
| `cluster upgrade addon <name>`              | Upgrade a single EKS addon                           |
| `cluster upgrade addons`                    | Upgrade all EKS addons as defined in cluster.yaml    |
| `cluster upgrade fast-end-to-end-automatic` | Automated end-to-end cluster upgrade (fast path)     |

### cordon

| Command                            | Description                                                 |
|------------------------------------|-------------------------------------------------------------|
| `cluster cordon node <name>`       | Cordon a single node to prevent new pods being scheduled    |
| `cluster cordon nodegroup <name>`  | Cordon all nodes in a nodegroup                             |
| `cluster cordon old-nodegroups`    | Cordon all nodes in nodegroups not defined in cluster.yaml  |

### uncordon

| Command                             | Description                                                   |
|-------------------------------------|---------------------------------------------------------------|
| `cluster uncordon node <name>`      | Uncordon a single node to allow pods to be scheduled again    |
| `cluster uncordon nodegroup <name>` | Uncordon all nodes in a nodegroup                             |
| `cluster uncordon old-nodegroups`   | Uncordon all nodes in nodegroups not defined in cluster.yaml  |

### drain

| Command                          | Description                                                |
|----------------------------------|------------------------------------------------------------|
| `cluster drain node <name>`      | Drain a single node, evicting all pods                     |
| `cluster drain nodegroup <name>` | Drain all nodes in a nodegroup                             |
| `cluster drain old-nodegroups`   | Drain all nodes in nodegroups not defined in cluster.yaml  |

### locksize

| Command                             | Description                                                    |
|-------------------------------------|----------------------------------------------------------------|
| `cluster locksize nodegroup <name>` | Lock a nodegroup size by setting min and max to current count  |
| `cluster locksize old-nodegroups`   | Lock the size of all nodegroups not defined in cluster.yaml    |

### set

| Command                                        | Description                          |
|------------------------------------------------|--------------------------------------|
| `cluster set nodegroup-min <name> <value>`     | Set the minimum size of a nodegroup  |
| `cluster set nodegroup-max <name> <value>`     | Set the maximum size of a nodegroup  |
| `cluster set nodegroup-desired <name> <value>` | Set the desired size of a nodegroup  |


## Utilities

| Command                     | Description                                                    |
|-----------------------------|----------------------------------------------------------------|
| `cluster validate-image`    | Validate the built image has everything it needs to operate    |
| `cluster setup-credentials` | Decrypt and set up AWS credentials from an age-encrypted file  |
| `cluster welcome`           | Welcome message displayed on login to the container            |


## kubectl Shortcuts

| Command                         | Description                                                               |
|---------------------------------|---------------------------------------------------------------------------|
| `k <args>`                      | Shorthand for `kubectl`                                                   |
| `k-system <args>`               | Shorthand for `kubectl -n kube-system`                                    |
| `k-default <args>`              | Shorthand for `kubectl -n default`                                        |
| `k-node-lease <args>`           | Shorthand for `kubectl -n kube-node-lease`                                |
| `k-public <args>`               | Shorthand for `kubectl -n kube-public`                                    |
| `k-run-platform <args>`         | Smart lookup: `kubectl -n <run-platform-*>` with caching                  |
| `k-run-env <args>`              | Smart lookup: `kubectl -n <run-*>` (excluding run-platform) with caching  |
| `k-exec-sh <namespace> <pod>`   | Exec into a pod with `/bin/sh`                                            |
| `k-exec-bash <namespace> <pod>` | Exec into a pod with `/bin/bash`                                          |
