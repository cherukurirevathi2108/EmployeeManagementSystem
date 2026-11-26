package DAO;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.List;

import model.TeamMember;

public class TeamMemberDAO {

    private Connection connection;

    public TeamMemberDAO(Connection connection) {
        this.connection = connection;
    }

    // Check whether employee is already an active member of the team
    public boolean isAlreadyMember(int teamId, int employeeId) {

        String sql = "SELECT id FROM team_members "
                   + "WHERE team_id = ? "
                   + "AND employee_id = ? "
                   + "AND status = 'ACTIVE'";

        try (PreparedStatement ps = connection.prepareStatement(sql)) {

            ps.setInt(1, teamId);
            ps.setInt(2, employeeId);

            ResultSet rs = ps.executeQuery();

            return rs.next();

        } catch (Exception e) {
            e.printStackTrace();
        }

        return false;
    }

    // Add employee to team
    public boolean addMember(int teamId, int employeeId) {

        String sql = "INSERT INTO team_members "
                   + "(team_id, employee_id, status) "
                   + "VALUES (?, ?, 'ACTIVE')";

        try (PreparedStatement ps = connection.prepareStatement(sql)) {

            ps.setInt(1, teamId);
            ps.setInt(2, employeeId);

            return ps.executeUpdate() > 0;

        } catch (Exception e) {
            e.printStackTrace();
        }

        return false;
    }

    // Remove employee from team
    // We do not delete the record permanently.
    public boolean removeMember(int teamId, int employeeId) {

        String sql = "UPDATE team_members "
                   + "SET status = 'INACTIVE' "
                   + "WHERE team_id = ? "
                   + "AND employee_id = ? "
                   + "AND status = 'ACTIVE'";

        try (PreparedStatement ps = connection.prepareStatement(sql)) {

            ps.setInt(1, teamId);
            ps.setInt(2, employeeId);

            return ps.executeUpdate() > 0;

        } catch (Exception e) {
            e.printStackTrace();
        }

        return false;
    }

    // Get all active members of a team
    public List<TeamMember> getTeamMembers(int teamId) {

        List<TeamMember> members = new ArrayList<>();

        String sql = "SELECT * FROM team_members "
                   + "WHERE team_id = ? "
                   + "AND status = 'ACTIVE' "
                   + "ORDER BY id";

        try (PreparedStatement ps = connection.prepareStatement(sql)) {

            ps.setInt(1, teamId);

            ResultSet rs = ps.executeQuery();

            while (rs.next()) {

                TeamMember member = new TeamMember();

                member.setId(rs.getInt("id"));
                member.setTeamId(rs.getInt("team_id"));
                member.setEmployeeId(rs.getInt("employee_id"));
                member.setJoinedDate(rs.getString("joined_date"));
                member.setStatus(rs.getString("status"));

                members.add(member);
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        return members;
    }

    // Get the active team of an employee
    public TeamMember getEmployeeTeam(int employeeId) {

        String sql = "SELECT * FROM team_members "
                   + "WHERE employee_id = ? "
                   + "AND status = 'ACTIVE' "
                   + "LIMIT 1";

        try (PreparedStatement ps = connection.prepareStatement(sql)) {

            ps.setInt(1, employeeId);

            ResultSet rs = ps.executeQuery();

            if (rs.next()) {

                TeamMember member = new TeamMember();

                member.setId(rs.getInt("id"));
                member.setTeamId(rs.getInt("team_id"));
                member.setEmployeeId(rs.getInt("employee_id"));
                member.setJoinedDate(rs.getString("joined_date"));
                member.setStatus(rs.getString("status"));

                return member;
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        return null;
    }

    // Count active members in a team
    public int getMemberCount(int teamId) {

        String sql = "SELECT COUNT(*) FROM team_members "
                   + "WHERE team_id = ? "
                   + "AND status = 'ACTIVE'";

        try (PreparedStatement ps = connection.prepareStatement(sql)) {

            ps.setInt(1, teamId);

            ResultSet rs = ps.executeQuery();

            if (rs.next()) {
                return rs.getInt(1);
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        return 0;
    }
}
