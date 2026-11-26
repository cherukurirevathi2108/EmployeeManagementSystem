package model;

public class TeamMember {

    private int id;
    private int teamId;
    private int employeeId;
    private String joinedDate;
    private String status;
    public TeamMember() {
    }

    public TeamMember(int id, int teamId, int employeeId,
                      String joinedDate, String status) {

        this.id = id;
        this.teamId = teamId;
        this.employeeId = employeeId;
        this.joinedDate = joinedDate;
        this.status = status;
    }

    public int getId() {
        return id;
    }

    public void setId(int id) {
        this.id = id;
    }

    public int getTeamId() {
        return teamId;
    }

    public void setTeamId(int teamId) {
        this.teamId = teamId;
    }

    public int getEmployeeId() {
        return employeeId;
    }

    public void setEmployeeId(int employeeId) {
        this.employeeId = employeeId;
    }

    public String getJoinedDate() {
        return joinedDate;
    }

    public void setJoinedDate(String joinedDate) {
        this.joinedDate = joinedDate;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }
}
