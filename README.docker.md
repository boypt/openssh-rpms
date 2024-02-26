## Wanna 🐳Docker?

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
VERSIONS=("7" "6" "5")
# Define whether to enable Tsinghua University mirror source. (Very useful for Chinese users)
CHINA_MIRROR=0  # Setting this variable to non-zero means enabling

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
  VERSIONS=("7" "6" "5")

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

#### Amazon Linux

##### Build images

```shell
# Specify build versions
VERSIONS=("2023" "2" "1")
# Define whether to enable China mirror source. (Very useful for Chinese users)
CHINA_MIRROR=0  # Setting this variable to non-zero means enabling

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
IMAGE_TAGS=("amzn2023" "amzn2" "amzn1" "el7" "el6" "el5")

for IMAGE_TAG in "${IMAGE_TAGS[@]}"
do
  # Start container
  docker run -it --rm \
         -v $OUT_PATH:/data/$IMAGE_TAG/RPMS \
         $COMPONENT:$IMAGE_TAG
done
```
