# TODO

## Restore

- Remove all socket logic?
- Append "IF NOT EXISTS" to MySQL metadata when creating backups; probably best for single source of truth
- Split up procedures & views into separate SQL backup files
- Consider restoring procedures & views in separate Job at the end using LoadBalancer

Problem:
    Views & procedures are not replicated; hence they won't be restored properly by the Job. We would have to run the
    MySQL restore for every single Pod startup. It might be risky though to restore everything *over and over again*.
    One could consider separating procedures and views into a separate SQL file.

## Backups

- Remove DROP TABLE from backups (?)
- Create metadata.json file (up for discussion, it is not strictly necessary)
- Test with OVH object storage

## Other

- Create more values.yaml files for production settings
- Make data node memory changeable
- Add YCSB to benchmark options
- Figure out how to run `SELECT count(*) FROM ndbinfo.nodes` as MySQL readiness check.
  - Using  `--defaults-file=$RONDB_DATA_DIR/my.cnf` and `GRANT SELECT ON ndbinfo.nodes TO 'hopsworks'@'%';` does not work
  - Error: `ERROR 1356 (HY000): View 'ndbinfo.nodes' references invalid table(s) or column(s) or function(s) or definer/invoker of view lack rights to use them`

Kubernetes Jobs to add:
- Increasing logfile group sizes
