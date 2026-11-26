package model;

/** Model for the Audit & System Management module. */
public class BackupHistory {

    private long id;
    private String backupFile;
    private String backupType;
    private String status;
    private long fileSize;
    private String createdBy;
    private java.sql.Timestamp createdAt;
    private String remarks;
    private String checksum;

    public long getId() { return id; }
    public void setId(long id) { this.id = id; }
    public String getBackupFile() { return backupFile; }
    public void setBackupFile(String backupFile) { this.backupFile = backupFile; }
    public String getBackupType() { return backupType; }
    public void setBackupType(String backupType) { this.backupType = backupType; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public long getFileSize() { return fileSize; }
    public void setFileSize(long fileSize) { this.fileSize = fileSize; }
    public String getCreatedBy() { return createdBy; }
    public void setCreatedBy(String createdBy) { this.createdBy = createdBy; }
    public java.sql.Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(java.sql.Timestamp createdAt) { this.createdAt = createdAt; }
    public String getRemarks() { return remarks; }
    public void setRemarks(String remarks) { this.remarks = remarks; }
    public String getChecksum() { return checksum; }
    public void setChecksum(String checksum) { this.checksum = checksum; }
}
