# AWS EKS Cluster Management

A comprehensive set of tools for managing EKS clusters on AWS.


## Image Contents

Based on Debian Trixie, we also install:

- **eksctl**     - EKS control plane, node group, and addon operations.
- **kubectl**    - Kubernetes API interactions eg cordon, drain and more.
- **AWS CLI v2** - Kube credentials and Utility in case of emergencies.
- **age**        - Decryption of secrets if included in the image.


## Multi-Architecture

Built for `linux/amd64` and `linux/arm64` for your ease of use.


## Usage

This image can be used for creation deletion and maintenance but the former two
are not done frequently (eg DR practice runs or when new). On the contrary the
normal use of this image is for 4 monthly (minimum) maintenance cycles, or more
often for addon upgrades or node group patching runs.

A normal maintenance run looks like this:

1. Ensure all components in the cluster are compatible with the target version
2. Run `cluster validate-image` to ensure it's viable
3. Run `cluster setup-credentials` to make the commands work
4. Run `cluster list all` to get the lay of the land
5. Run `cluster upgrade addons` to get the addons up to date as a base line
6. Run `cluster upgrade cluster` upgrade control plane and create new nodegroups
7. Run `cluster cordon oldnodegroups` to prevent workloads starting up on them
8. Delete a low-impact pod and ensure it starts up fine on the new node group(s)
9. Gently and thoughtfully migrate any singletons or other senstive workloads
10. Run `cluster drain oldnodegroups` to migrate any remaining workloads
11. Confirm everything you care about is running and working fine
12. Run `cluster delete oldnodegroups` to remove the empty unused nodes
13. Run `cluster upgrade addons` to get the addons up to date and matching
14. Upgrade other components within the cluster to match

To create a new cluster just:

1. Run `cluster validate-image` to ensure it's viable
2. Run `cluster setup-credentials` to make the commands work
3. Run `cluster create --dry-run` and ensure it looks good and as expected
4. Run `cluster create` and ensure it creates smoothly and without errors
5. Run `cluster list all` to see what you created
6. Bootstrap/seed the cluster with tooling and workloads - easy if kaptain

To delete a cluster for DR testing or other reasons, just:

1. Run `cluster validate-image` to ensure it's viable
2. Run `cluster setup-credentials` to make the commands work
3. Run `cluster delete cluster` and type in the requested values to confirm
4. Run `cluster list all` to ensure there's nothing left
5. Clean up any external resources that the cluster was managing eg DNS/LBs
6. Cry if you got it wrong, party if you got it right :-D

