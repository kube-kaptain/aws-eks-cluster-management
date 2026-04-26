# Image AWS EKS Cluster Management

A comprehensive set of tools for managing EKS clusters on AWS.

For the full list of available commands see the [Command Reference](CommandReference.md).

For why this toolkit is the best approach for managing EKS on AWS and why
Terraform, OpenTofu and other declarative tools are usually the wrong choice,
see [Why Not Terraform?](WhyNotTerraform.md).


## Image Contents

Based on Debian Trixie, we also install:

- **eksctl**     - EKS control plane, node group, and addon operations.
- **kubectl**    - Kubernetes API interactions eg cordon, drain and more.
- **AWS CLI v2** - Kube credentials and Utility in case of emergencies.
- **age**        - Decryption of secrets if included in the image.


## Multi-Architecture

Built for `linux/amd64` and `linux/arm64` for your ease of use.


## Usage

To use this image the best approach is to use a Kaptain build process and layer
or layerset. Right now only GitHub Actions workflows are available, so below
are links to the example file for the correct workflow for use with the layer(set)
as well as to the layer and layerset themselves where more info on config and
setup is available.

* [Layer AWS EKS Cluster Management](https://github.com/kube-kaptain/layer-aws-eks-cluster-management) provides a strict specialist build for this image
* [Layerset AWS EKS Cluster Management](https://github.com/kube-kaptain/layerset-aws-eks-cluster-management) combines the above layer with [GitHub Flow Strict](https://github.com/kube-kaptain/layer-github-flow-strict)
* [Kaptain GH Actions example workflow](https://github.com/kube-kaptain/buildon-github-actions/blob/main/examples/basic-quality-and-versioning.yaml) is the required build type to match the layer

The [layer README.md](https://github.com/kube-kaptain/layer-aws-eks-cluster-management#layer-aws-eks-cluster-management) gives information on how to configure your project.


## Use Patterns

This image can be used for creation deletion and maintenance but the former two
are not done frequently (eg DR practice runs or when new). On the contrary the
normal use of this image is for 4 monthly (minimum) maintenance cycles, or more
often for addon upgrades or node group patching runs.


### Normal Maintenance

A normal 4 monthly maintenance run looks like this:

1. Ensure all components in the cluster are compatible with the target version
2. Run `cluster validate-image` to ensure it's viable
3. Run `cluster setup-credentials` to make the commands work
4. Run `cluster list all` to get the lay of the land
5. Run `cluster list insights` to review any advisories and decide whether to proceed
6. If more detail is needed run `cluster describe insight <ID>` for each
7. Run `cluster upgrade prepare-for-migration` to perform all non-disruptive steps
8. Delete a low-impact pod and ensure it starts up fine on the new nodegroup(s)
9. Gently and thoughtfully migrate any singletons or other sensitive workloads
10. Run `cluster drain old-nodegroups` to migrate any remaining workloads
11. Confirm everything you care about is running and working fine
12. Run `cluster delete old-nodegroups` to remove the empty unused nodes
13. Run `cluster upgrade yaml-reconciliation` to ensure cluster matches cluster.yaml
    WARNING: ensure toggling auto mode won't disrupt your workloads before running
14. Upgrade other components within the cluster to match

You can perform the individual steps instead of step 7 if you prefer:

* Run `cluster upgrade addons` to get the addons up to date as a base line
* Run `cluster upgrade controlplane` to upgrade the control plane version
* Run `cluster upgrade addons` to bring the addons into line with the control plane
* Run `cluster create nodegroups` to create new nodegroup(s) to migrate workloads onto
* Run `cluster locksize old-nodegroups` to prevent autoscaler scaling old nodegroups
* Run `cluster cordon old-nodegroups` to prevent workloads starting up on them

Or if your workloads are resilient (multiple replicas, PDBs, all three probes,
termination grace period, graceful shutdown) you can run the automated version:

Full-auto: `cluster upgrade fast-end-to-end-automatic`

However clusters with 100% perfectly configured workloads are rarer than hen's
teeth. If you do this with singletons or misconfigured workloads you'll probably
experience outages during this process; take the slower route, instead.


### Nodegroups-Only Maintenance

If you patch your nodes more frequently than the Kubernetes minor version release
cycle, or need to change the instance type or disk size or disk type etc then this
is the section for you.

When the control plane and addons are already up-to-date and you only need to
replace the nodegroups with new/different ones:

1. Run `cluster validate-image` to ensure it's viable
2. Run `cluster setup-credentials` to make the commands work
3. Run `cluster list all` to get the lay of the land
4. Run `cluster upgrade prepare-nodegroups-only` to create new nodegroups and cordon/lock old ones
5. Delete a low-impact pod and ensure it starts up fine on the new nodegroup(s)
6. Gently and thoughtfully migrate any singletons or other sensitive workloads
7. Run `cluster drain old-nodegroups` to migrate any remaining workloads
8. Confirm everything you care about is running and working fine
9. Run `cluster delete old-nodegroups` to remove the empty unused nodes
10. Upgrade other components within the cluster to match

Or if your workloads are resilient (multiple replicas, PDBs, all three probes,
termination grace period, graceful shutdown) you can run the automated version:

Full-auto: `cluster upgrade fast-nodegroups-only-automatic`


### Backing Out a Nodegroup Migration

If the new nodegroups have problems and you need to revert, the new-nodegroups
commands mirror the old-nodegroups commands with the selection inverted:

1. Run `cluster uncordon old-nodegroups` to allow scheduling on old nodegroups again
2. Run `cluster unlocksize old-nodegroups` to restore original min/max on old nodegroups
3. Run `cluster locksize new-nodegroups` to prevent autoscaler scaling new nodegroups
4. Run `cluster cordon new-nodegroups` to stop workloads scheduling on new nodegroups
5. Run `cluster drain new-nodegroups` to move workloads back to old nodegroups
6. Confirm everything is running on the old nodegroups
7. Run `cluster delete new-nodegroups` to remove the new nodegroups


### Cluster Creation

To create a new cluster just:

1. Run `cluster validate-image` to ensure it's viable
2. Run `cluster setup-credentials` to make the commands work
3. Run `cluster create cluster --dry-run` and ensure it looks good and as expected
4. Run `cluster create cluster` and ensure it creates smoothly and without errors
5. Run `cluster list all` to see what you created
6. Bootstrap/seed the cluster with tooling and workloads - easy if kaptain


### Cluster Deletion

To delete a cluster for DR testing or other reasons, just:

1. Run `cluster validate-image` to ensure it's viable
2. Run `cluster setup-credentials` to make the commands work
3. Run `cluster delete cluster` and type in the requested values to confirm
4. Run `cluster list all` to ensure there's nothing left
5. Clean up any external resources that the cluster was managing eg DNS/LBs
6. Cry if you got it wrong, party if you got it right :-D

