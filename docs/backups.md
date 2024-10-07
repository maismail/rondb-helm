# Backups

## Background info

- Backup Pod cannot be guaranteed access to volumes of data nodes (volumes can have ReadWriteOnce, depending on cloud)
- Native RonDB backups are performed on every replica of a node group
- Writing a backup directly into object storage is a bad idea; S3 has no append option; it would do unnecessarily many writes
- CSI storage drivers are neat, but more less transparent and thereby tricky to handle

## Backup structure

Backups are stored with the following file structure. `backup-id` is a 32-bit uint, used by RonDB natively.

```bash
<backup-id>
    users.sql  # MySQL user metadata
    databases.sql  # MySQL table metadata (including procedures & views)
    rondb  # Native RonDB data backup
        <datanode-node-id>
            BACKUP-<backup-id>-PART-1-OF-2/
            BACKUP-<backup-id>-PART-2-OF-2/
        <datanode-node-id>
            BACKUP-<backup-id>-PART-1-OF-2/
            BACKUP-<backup-id>-PART-2-OF-2/
        ...
```

The SQL files are generated by the MySQL servers whilst the native backups are created by the data nodes. The latter is triggered by the RonDB management client. The SQL files are not strictly necessary to restore the backup but can be helpful in the event of bugs. Also, the native backup does not contain MySQL views and procedures.

## Adding support for a new object storage

We use `rclone` to upload backups to object storage. `Rclone` is installed in the `hopsworks/hwutils` image and it works for many different object storages, including OVH. To add support for a new object storage type, you need to add a configuration setting to rclone. For S3, this can look as follows:

```yaml
[myS3Remote]
type = s3
provider = AWS

# If using a credentials Secret:
access_key_id = blabla
secret_access_key = foofoo

# If using IAM roles (and running in cloud K8s):
env_auth = true
```

An easy way of creating this file is to run `docker run --rm -it --entrypoint=/bin/bash rclone/rclone:latest` which will open a terminal in a rclone image. There you can run:

```bash
# This will open an interactive process where you can specify your object storage 
rclone config
# After this is done, run this to see where your config file is placed
rclone config file
```