FROM debian:trixie-20260112-slim
# Always use the most specific tag possible

# Architecture from build system (used for binary downloads)
ARG DOCKER_PLATFORM_CPU_ARCHITECTURE

# Tool versions
ENV EKSCTL_VERSION=0.223.0
ENV KUBECTL_VERSION=1.32.13
ENV AWS_CLI_VERSION=2.33.31
ENV AGE_VERSION=1.3.1

# AWS CLI architecture mappings (URL uses x86_64/aarch64, checksums use amd/arm)
ENV AWS_CLI_URL_ARCH_amd64=x86_64
ENV AWS_CLI_URL_ARCH_arm64=aarch64

# Strong checksums to match the above (per architecture)
ENV EKSCTL_SHA512_amd64=f88c26bfe41a08ac61e6a6352e7538a514a0a38139b2db2f1f8a41d6336d4d5df993cfa2e34894efb23baffa0ee90e68172def6df1d3552a0ee97f285e9b7155
ENV EKSCTL_SHA512_arm64=4c79edd0a7bc87fb2388fb7ccdf6bbbbc63d4716921c4fb6fa702759e6eb5db2395a4d92bc6c1349bad1b1f72a1480c0c9a8e40762da123c57b8a85e5e778440
ENV KUBECTL_SHA512_amd64=8463c0546deeb6441b9b44909a104bc920ee32e6eb4a8e434b2ec2d1b3bb2806f8e6df8379db8b5b4d913d6b1a81f385910e2567b9b1537867dbdb0090b72a5d
ENV KUBECTL_SHA512_arm64=8023d3736e556b893732cc732df6b38fac8b710a9f6eac5fae0ac708af8823e932422666301360851ac83b95d21a5d93304b54691c6df669c4f3ddd16c79bdf5
ENV AGE_SHA512_amd64=425e3f7bcd3bee2ac5e356d45f86b208a15a4ddf0c5fe512047fbe08d77a4b957b3c5db699c49c281bd20f8bc1e76ab93753ab99593ff747742808769dccc070
ENV AGE_SHA512_arm64=7f7920f5f199e46b568bec464e870fd61baae67140ddb5ed104c458ee89cdfbb7c4f48873cfa73c1218dc2a023227e7bacf635480e678a480aeac04e0f330b1f

# Leave a trail of breadcrumbs
LABEL base.project.name="${ProjectName}"
LABEL base.version="${Version}"
LABEL base.docker.tag="${DockerTag}"
LABEL base.docker.image.name="${DockerImageName}"

# Install necessary tools and update packages
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get dist-upgrade -y
RUN apt-get install \
    ca-certificates \
    curl \
    debianutils \
    dnsutils \
    iputils-ping \
    netcat-openbsd \
    openssl \
    procps \
    time \
    unzip \
    -y --no-install-recommends
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*

# Install eksctl
RUN curl -sLo /tmp/eksctl.tar.gz "https://github.com/eksctl-io/eksctl/releases/download/v${EKSCTL_VERSION}/eksctl_Linux_${DOCKER_PLATFORM_CPU_ARCHITECTURE}.tar.gz"
RUN sha512sum /tmp/eksctl.tar.gz
RUN eval CHECKSUM=\$EKSCTL_SHA512_${DOCKER_PLATFORM_CPU_ARCHITECTURE} && \
    echo "${CHECKSUM}  /tmp/eksctl.tar.gz" | sha512sum -c -
RUN tar xzf /tmp/eksctl.tar.gz -C /usr/local/bin eksctl
RUN rm /tmp/eksctl.tar.gz

# Install kubectl
RUN curl -sLo /usr/local/bin/kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${DOCKER_PLATFORM_CPU_ARCHITECTURE}/kubectl"
RUN sha512sum /usr/local/bin/kubectl
RUN eval CHECKSUM=\$KUBECTL_SHA512_${DOCKER_PLATFORM_CPU_ARCHITECTURE} && \
    echo "${CHECKSUM}  /usr/local/bin/kubectl" | sha512sum -c -
RUN chmod +x /usr/local/bin/kubectl

# Install AWS CLI v2 (checksums fetched from aws-cli-v2-index)
RUN eval URL_ARCH=\$AWS_CLI_URL_ARCH_${DOCKER_PLATFORM_CPU_ARCHITECTURE} && \
    curl -sLo /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-${URL_ARCH}-${AWS_CLI_VERSION}.zip"
RUN eval CHECKSUM_ARCH=\$AWS_CLI_CHECKSUM_ARCH_${DOCKER_PLATFORM_CPU_ARCHITECTURE} && \
    curl -sLo /tmp/awscli.sha512 "https://github.com/kube-kaptain/aws-cli-v2-index/releases/download/${AWS_CLI_VERSION}/${CHECKSUM_ARCH}.sha512"
RUN sha512sum /tmp/awscliv2.zip
RUN CHECKSUM=$(cat /tmp/awscli.sha512) && \
    echo "${CHECKSUM}  /tmp/awscliv2.zip" | sha512sum -c -
RUN unzip -q /tmp/awscliv2.zip -d /tmp
RUN /tmp/aws/install
RUN rm -rf /tmp/aws /tmp/awscliv2.zip /tmp/awscli.sha512

# Install age (pinned version, not from distro repos)
RUN curl -sLo /tmp/age.tar.gz "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-${DOCKER_PLATFORM_CPU_ARCHITECTURE}.tar.gz"
RUN sha512sum /tmp/age.tar.gz
RUN eval CHECKSUM=\$AGE_SHA512_${DOCKER_PLATFORM_CPU_ARCHITECTURE} && \
    echo "${CHECKSUM}  /tmp/age.tar.gz" | sha512sum -c -
RUN tar xzf /tmp/age.tar.gz -C /usr/local/bin --strip-components=1 age/age age/age-keygen
RUN rm /tmp/age.tar.gz

# Create directory structure
RUN mkdir -p /kd/bin      # Cluster management scripts
RUN mkdir -p /kd/work     # Writeable directory audit trail and whatever else you need
RUN mkdir -p /kd/secrets  # Encrypted cluster management credentials (optional)
RUN mkdir -p /kd/eks      # Home for cluster.yaml and variants

# Use these directories
ENV PATH="/kd/bin:${PATH}"
WORKDIR /kd

# Create cluster maintenance user
ENV KAPTAIN_USER_ID=4242
RUN mkdir -p /home/kaptain
RUN groupadd -g ${KAPTAIN_USER_ID} kaptain
RUN useradd -u ${KAPTAIN_USER_ID} -g kaptain -d /home/kaptain -s /bin/bash kaptain
RUN chown kaptain:kaptain /home/kaptain /kd/work
# Final use downstream image should set USER for immutability in use

# TODO write the scripts and write the script to copy them to context in a hook call - wait till I tell you what to write on this one 
COPY scripts/* /kd/bin/

# TODO prompt taht works no matter what with echos for instructions - I'll provide instruciton on how to do this one - don't do it until I give you the instructions 
