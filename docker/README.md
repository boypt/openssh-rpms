## Wanna 🐳Docker?

### TLDR

#### I JUST WANT RPMS

This script below can compile rpm packages for all systems.

```bash
# Download all src files
source version.env
PERLMIR=https://www.cpan.org/src/5.0
if [[ ! -f downloads/$PERLSRC ]]; then
	curl -k -o downloads/$PERLSRC $PERLMIR/$PERLSRC
fi
bash ./pullsrc.sh
# Define whether to enable Tsinghua University mirror source. (Very useful for Chinese users)
CHINA_MIRROR=1  # Setting this variable to non-zero means enabling
OUTPUT="/tmp"

# Specify build CentOS versions
VERSIONS=("7" "6" "5")

for VERSION in "${VERSIONS[@]}"
do
  echo "Building CentOS: ${VERSION}"
  # Build docker image
  docker build \
         -t rpm-builder-centos:$VERSION \
         --build-arg VERSION_NUM=$VERSION \
         --build-arg CHINA_MIRROR=$CHINA_MIRROR \
         -f docker/Dockerfile.centos .
  mkdir -p $OUTPUT/centos/$VERSION
  # Start container
  docker run -it --rm \
         -v $OUTPUT/centos/$VERSION:/data/el$VERSION/RPMS/$(uname -m) \
         rpm-builder-centos:$VERSION
done

# Specify build CentOS Stream versions
VERSIONS=("9" "8")

for VERSION in "${VERSIONS[@]}"
do
  echo "Building CentOS Stream: ${VERSION}"
  # Build docker image
  docker build \
         -t rpm-builder-centos-stream:$VERSION \
         --build-arg VERSION_NUM=$VERSION \
         --build-arg CHINA_MIRROR=$CHINA_MIRROR \
         -f docker/Dockerfile.centos-stream .
  mkdir -p $OUTPUT/centos-stream/$VERSION
  # Start container
  docker run -it --rm \
         -v $OUTPUT/centos-stream/$VERSION:/data/el7/RPMS/$(uname -m) \
         rpm-builder-centos-stream:$VERSION
done

# Specify build Amazon Linux versions
VERSIONS=("2023" "2" "1")

for VERSION in "${VERSIONS[@]}"
do
  echo "Building version: ${VERSION}"
  # Build docker image
  docker build \
         -t rpm-builder-amazonlinux:$VERSION \
         --build-arg VERSION_NUM=$VERSION \
         --build-arg CHINA_MIRROR=$CHINA_MIRROR \
         -f docker/Dockerfile.amazonlinux .
  mkdir -p $OUTPUT/amazonlinux/$VERSION
  # Start container
  docker run -it --rm \
         -v $OUTPUT/amazonlinux/$VERSION:/data/amzn$VERSION/RPMS/$(uname -m) \
         rpm-builder-amazonlinux:$VERSION
done

```

#### I WANT UPLOAD TO NEXUS REPOSITORY

```bash
# Define output dir
OUTPUT='/tmp'
# Define upload auth info
export NEXUS_REPOSITORY_URL='https://nexus.example.com/service/rest/v1/components?repository=my-yum-hosted'
export NEXUS_USERNAME='uploader'
export NEXUS_PASSWORD='Pa$$w0rD'

declare -A MAPPING
MAPPING["centos"]="7 6 5"
MAPPING["centos-stream"]="9 8"
MAPPING["amazonlinux"]="2023 2 1"

function upload_file(){
  echo "Uploading: $1"
  echo "Destination: $2"
  curl \
    --user "$NEXUS_USERNAME:$NEXUS_PASSWORD" \
    $NEXUS_REPOSITORY_URL \
    -H 'accept: application/json' \
    -H 'Content-Type: multipart/form-data' \
    -F "yum.directory=$2" \
    -F "yum.asset=@$1;type=application/x-rpm" \
    -F "yum.asset.filename=$(basename $1)"
}
export -f upload_file

for OS_TYPE in "${!MAPPING[@]}"; do
    VERSIONS=${MAPPING[$OS_TYPE]}
    VERSIONS_ARRAY=($VERSIONS)

    # If you need a clearer structure, uncomment the following
    __OS_TYPE=$OS_TYPE
    if [ "$OS_TYPE" = 'centos-stream' ];then __OS_TYPE='centos';fi
    
    for VERSION in "${VERSIONS_ARRAY[@]}"; do
        echo "$OS_TYPE $VERSION"
        find $OUTPUT/$OS_TYPE/$VERSION \
          -type f \
          -name '*.rpm' \
          -exec bash -c 'upload_file "$1" "$2"' _ {} "$__OS_TYPE/$VERSION/$(uname -m)" \;
    done
done
```

### Create image

#### Login registry

```shell
# Login info
USERNAME='User'
PASSWORD='Pa$$W0rd'
# Registry URL, leave it blank will use docker offcial registry: registry-1.docker.io
SERVER='harbor.example.com'

docker login -u "$USERNAME" -p "$PASSWORD" "$SERVER"

# Define the path of compenent
COMPONENT="$SERVER/cloudteam/openssh-rpm-builder"
```

#### CentOS

##### Build images

```shell
# Specify build versions
VERSIONS=("8" "7" "6" "5")
# Define whether to enable Tsinghua University mirror source. (Very useful for Chinese users)
CHINA_MIRROR=1  # Setting this variable to non-zero means enabling

for VERSION in "${VERSIONS[@]}"
do
  echo "Building version: ${VERSION}"
  # Build docker image
  docker build \
         -t $COMPONENT:centos$VERSION \
         --build-arg VERSION_NUM=$VERSION \
         --build-arg CHINA_MIRROR=$CHINA_MIRROR \
         -f docker/Dockerfile.centos .
done

echo 'The building has been completed!'
```

##### Push images

```shell
# Specify build versions
VERSIONS=("8" "7" "6" "5")

for VERSION in "${VERSIONS[@]}"
do
  echo "Pushing version: ${VERSION}"
  # Tag image
  docker tag $COMPONENT:centos$VERSION $COMPONENT:centos.$VERSION
  docker tag $COMPONENT:centos$VERSION $COMPONENT:centos.$VERSION.$(date +%Y%m%d)
  docker tag $COMPONENT:centos$VERSION $COMPONENT:el$VERSION
  # Push image
  docker push $COMPONENT:centos$VERSION
  docker push $COMPONENT:centos.$VERSION
  docker push $COMPONENT:centos.$VERSION.$(date +%Y%m%d)
  docker push $COMPONENT:el$VERSION
done
echo 'Push has been completed!'
```

#### CentOS Stream

##### Build images

```shell
# Specify build versions
VERSIONS=("9" "8")
# Define whether to enable Tsinghua University mirror source. (Very useful for Chinese users)
CHINA_MIRROR=1  # Setting this variable to non-zero means enabling

for VERSION in "${VERSIONS[@]}"
do
  echo "Building version: ${VERSION}"
  # Build docker image
  docker build \
         -t $COMPONENT:centos-stream$VERSION \
         --build-arg VERSION_NUM=$VERSION \
         --build-arg CHINA_MIRROR=$CHINA_MIRROR \
         -f docker/Dockerfile.centos-stream .
done

echo 'The building has been completed!'
```

##### Push images

```shell
# Specify build versions
VERSIONS=("9" "8")

for VERSION in "${VERSIONS[@]}"
do
  echo "Pushing version: ${VERSION}"
  # Tag image
  docker tag $COMPONENT:centos-stream$VERSION $COMPONENT:centos-stream.$VERSION
  docker tag $COMPONENT:centos-stream$VERSION $COMPONENT:centos-stream.$VERSION.$(date +%Y%m%d)
  docker tag $COMPONENT:centos-stream$VERSION $COMPONENT:el$VERSION
  # Push image
  docker push $COMPONENT:centos-stream$VERSION
  docker push $COMPONENT:centos-stream.$VERSION
  docker push $COMPONENT:centos-stream.$VERSION.$(date +%Y%m%d)
  docker push $COMPONENT:el$VERSION
done
echo 'Push has been completed!'
```

#### Amazon Linux

##### Build images

```shell
# Specify build versions
VERSIONS=("2023" "2" "1")
# Define whether to enable China mirror source. (Very useful for Chinese users)
CHINA_MIRROR=1  # Setting this variable to non-zero means enabling

for VERSION in "${VERSIONS[@]}"
do
  echo "Building version: ${VERSION}"
  # Build docker image
  docker build \
         -t $COMPONENT:amazonlinux$VERSION \
         --build-arg VERSION_NUM=$VERSION \
         --build-arg CHINA_MIRROR=$CHINA_MIRROR \
         -f docker/Dockerfile.amazonlinux .
done
echo 'The building has been completed!'
```

##### Push images

```shell
# Specify build versions
VERSIONS=("2023" "2" "1")

for VERSION in "${VERSIONS[@]}"
do
  echo "Pushing version: ${VERSION}"
  # Tag image
  docker tag $COMPONENT:amazonlinux$VERSION $COMPONENT:amazonlinux.$VERSION
  docker tag $COMPONENT:amazonlinux$VERSION $COMPONENT:amazonlinux.$VERSION.$(date +%Y%m%d)
  docker tag $COMPONENT:amazonlinux$VERSION $COMPONENT:amzn$VERSION
  docker tag $COMPONENT:amazonlinux$VERSION $COMPONENT:al$VERSION
  # Push image
  docker push $COMPONENT:amazonlinux$VERSION
  docker push $COMPONENT:amazonlinux.$VERSION
  docker push $COMPONENT:amazonlinux.$VERSION.$(date +%Y%m%d)
  docker push $COMPONENT:amzn$VERSION
  docker push $COMPONENT:al$VERSION
done
echo 'Push has been completed!'
```

### Use image

#### Single OS

```shell
# Specify the name of tag.
IMAGE_TAG="amzn2023"
# Specify output path
OUT_PATH="$PWD"

mkdir -p $OUT_PATH

# Start container
docker run -it --rm \
       -v $OUT_PATH:/data/$IMAGE_TAG/RPMS \
       $COMPONENT:$IMAGE_TAG
```

#### Multi OS

```shell
# Specify output path
OUT_PATH="$PWD"

# Specify the name of tags.
IMAGE_TAGS=("amzn2023" "amzn2" "amzn1" "el9" "el8" "el7" "el6" "el5")

for IMAGE_TAG in "${IMAGE_TAGS[@]}"
do
  # Start container
  docker run -it --rm \
         -v $OUT_PATH:/data/$IMAGE_TAG/RPMS \
         $COMPONENT:$IMAGE_TAG
done
```

## For ARM users

- *CentOS 6 and lower operating systems **DO NOT** have an image of the ARM architecture.*

- *Amazon Linux 1 **DO NOT** have an image of the ARM architecture.*

#### I JUST WANT RPMS

This script below can compile rpm packages for all support systems.

```bash
# Download all src files
source version.env
PERLMIR=https://www.cpan.org/src/5.0
if [[ ! -f downloads/$PERLSRC ]]; then
	curl -k -o downloads/$PERLSRC $PERLMIR/$PERLSRC
fi
bash ./pullsrc.sh
# Define whether to enable Tsinghua University mirror source. (Very useful for Chinese users)
CHINA_MIRROR=1  # Setting this variable to non-zero means enabling
OUTPUT="/tmp"

# Specify build CentOS versions
VERSION="7"

echo "Building CentOS: ${VERSION}"
# Build docker image
docker build \
       -t rpm-builder-centos:$VERSION \
       --build-arg VERSION_NUM=$VERSION \
       --build-arg CHINA_MIRROR=$CHINA_MIRROR \
       -f docker/Dockerfile.centos .
mkdir -p $OUTPUT/centos/$VERSION
# Start container
docker run -it --rm \
       -v $OUTPUT/centos/$VERSION:/data/el7/RPMS/$(uname -m) \
       rpm-builder-centos:$VERSION

# Specify build CentOS Stream versions
VERSIONS=("9" "8")

for VERSION in "${VERSIONS[@]}"
do
  echo "Building CentOS Stream: ${VERSION}"
  # Build docker image
  docker build \
         -t rpm-builder-centos-stream:$VERSION \
         --build-arg VERSION_NUM=$VERSION \
         --build-arg CHINA_MIRROR=$CHINA_MIRROR \
         -f docker/Dockerfile.centos-stream .
  mkdir -p $OUTPUT/centos-stream/$VERSION
  # Start container
  docker run -it --rm \
         -v $OUTPUT/centos-stream/$VERSION:/data/el7/RPMS/$(uname -m) \
         rpm-builder-centos-stream:$VERSION
done

# Specify build Amazon Linux versions
VERSIONS=("2023" "2")

for VERSION in "${VERSIONS[@]}"
do
  echo "Building version: ${VERSION}"
  # Build docker image
  docker build \
         -t rpm-builder-amazonlinux:$VERSION \
         --build-arg VERSION_NUM=$VERSION \
         --build-arg CHINA_MIRROR=$CHINA_MIRROR \
         -f docker/Dockerfile.amazonlinux .
  mkdir -p $OUTPUT/amazonlinux/$VERSION
  # Start container
  docker run -it --rm \
         -v $OUTPUT/amazonlinux/$VERSION:/data/amzn$VERSION/RPMS/$(uname -m) \
         rpm-builder-amazonlinux:$VERSION
done

```

#### I WANT UPLOAD TO NEXUS REPOSITORY

```bash
# Define output dir
OUTPUT='/tmp'
# Define upload auth info
export NEXUS_REPOSITORY_URL='https://nexus.example.com/service/rest/v1/components?repository=my-yum-hosted'
export NEXUS_USERNAME='uploader'
export NEXUS_PASSWORD='Pa$$w0rD'

declare -A MAPPING
MAPPING["centos"]="7"
MAPPING["centos-stream"]="9 8"
MAPPING["amazonlinux"]="2023 2 1"

function upload_file(){
  echo "Uploading: $1"
  echo "Destination: $2"
  curl \
    --user "$NEXUS_USERNAME:$NEXUS_PASSWORD" \
    $NEXUS_REPOSITORY_URL \
    -H 'accept: application/json' \
    -H 'Content-Type: multipart/form-data' \
    -F "yum.directory=$2" \
    -F "yum.asset=@$1;type=application/x-rpm" \
    -F "yum.asset.filename=$(basename $1)"
}
export -f upload_file

for OS_TYPE in "${!MAPPING[@]}"; do
    VERSIONS=${MAPPING[$OS_TYPE]}
    VERSIONS_ARRAY=($VERSIONS)

    # If you need a clearer structure, uncomment the following
    __OS_TYPE=$OS_TYPE
    if [ "$OS_TYPE" = 'centos-stream' ];then __OS_TYPE='centos';fi
    
    for VERSION in "${VERSIONS_ARRAY[@]}"; do
        echo "$OS_TYPE $VERSION"
        find $OUTPUT/$OS_TYPE/$VERSION \
          -type f \
          -name '*.rpm' \
          -exec bash -c 'upload_file "$1" "$2"' _ {} "$__OS_TYPE/$VERSION/$(uname -m)" \;
    done
done
```
