CREATE TABLE t1 (
    id INT NOT NULL,
    date DATETIME DEFAULT CURRENT_TIMESTAMP,
    str VARCHAR(500),
    rid_t2_k_fid_t1 INT NOT NULL,
    rid_t3_k_fid_t1 INT NOT NULL,
    rid_t4_k_fid_t1 INT NOT NULL,
    rid_t4_k_fchar_t1 CHAR(20) NOT NULL,
    rid_t4_k_fid2_t1 INT NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT k_rid_t2_fid_t1 FOREIGN KEY (rid_t2_k_fid_t1) REFERENCES t2 (fid_t1) ON DELETE CASCADE,
    CONSTRAINT k_rid_t3_fid_t1 FOREIGN KEY (rid_t3_k_fid_t1) REFERENCES t3 (fid_t1) ON DELETE CASCADE,
    CONSTRAINT k_rid_t4_fid_t1 FOREIGN KEY (
        rid_t4_k_fid_t1,
        rid_t4_k_fchar_t1,
        rid_t4_k_fid2_t1
    ) REFERENCES t4 (fid_t1, fchar_t1, fid2_t1) ON DELETE CASCADE
) TABLESPACE ts_1 STORAGE DISK ENGINE = NDB;
