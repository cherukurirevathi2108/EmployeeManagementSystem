package model;

/** Model for the Audit & System Management module. */
public class SystemError {

    private long id;
    private String moduleName;
    private String errorType;
    private String errorMessage;
    private String severity;
    private String userId;
    private java.sql.Timestamp createdAt;

    public long getId() { return id; }
    public void setId(long id) { this.id = id; }
    public String getModuleName() { return moduleName; }
    public void setModuleName(String moduleName) { this.moduleName = moduleName; }
    public String getErrorType() { return errorType; }
    public void setErrorType(String errorType) { this.errorType = errorType; }
    public String getErrorMessage() { return errorMessage; }
    public void setErrorMessage(String errorMessage) { this.errorMessage = errorMessage; }
    public String getSeverity() { return severity; }
    public void setSeverity(String severity) { this.severity = severity; }
    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }
    public java.sql.Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(java.sql.Timestamp createdAt) { this.createdAt = createdAt; }
}
