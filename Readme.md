Instructions here:
```
sudo yum install git
 sudo apt install software-properties-common
 sudo apt-add-repository --yes --update ppa:ansible/ansible
 sudo apt install ansible

export JETSON_ROOTFS_DIR=/hom/mdt/jetson/rootfs
sudo -E ./create-rootfs.sh
cd ansible
cat <<EOF> $JETSON_ROOTFS_DIR/etc/resolv.conf
nameserver 8.8.8.8
EOF

sudo -E $(which ansible-playbook) jetson.yaml
export JETSON_BUILD_DIR=/home/mdt/jetson/build_dir
sudo -E ./create-image.sh

```

Install AI dependency
```
chroot inside chroot

run install-env.sh file

After that please install your AI dependency. you can use apt install *.dev

after that please login to docker hub

pull your image and logout

```