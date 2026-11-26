package model;

/** Model for the Audit & System Management module. */
public class LoginHistory {

    private long id;
    private String userId;
    private String userRole;
    private String email;
    private String activityType;
    private String ipAddress;
    private String userAgent;
    private java.sql.Timestamp createdAt;

    public long getId() { return id; }
    public void setId(long id) { this.id = id; }
    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }
    public String getUserRole() { return userRole; }
    public void setUserRole(String userRole) { this.userRole = userRole; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getActivityType() { return activityType; }
    public void setActivityType(String activityType) { this.activityType = activityType; }
    public String getIpAddress() { return ipAddress; }
    public void setIpAddress(String ipAddress) { this.ipAddress = ipAddress; }
    public String getUserAgent() { return userAgent; }
    public void setUserAgent(String userAgent) { this.userAgent = userAgent; }
    public java.sql.Timestamp getCreatedAt() { return createdAt; }
    public void setCreatedAt(java.sql.Timestamp createdAt) { this.createdAt = createdAt; }
}
