package DAO;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.List;

import model.Team;

public class TeamDAO {

    private Connection connection;

    public TeamDAO(Connection connection) {
        this.connection = connection;
    }

    // ==============================
    // CHECK TEAM NAME
    // ==============================

    public boolean teamNameExists(String teamName) {

        String sql =
            "SELECT id FROM teams WHERE team_name = ?";

        try (PreparedStatement ps =
                 connection.prepareStatement(sql)) {

            ps.setString(1, teamName);

            ResultSet rs = ps.executeQuery();

            return rs.next();

        } catch (Exception e) {

            e.printStackTrace();

        }

        return false;
    }


    // ==============================
    // CREATE TEAM
    // ==============================

    public boolean createTeam(Team team) {

        String sql =
            "INSERT INTO teams " +
            "(team_name, description, department, manager_id, status) " +
            "VALUES (?, ?, ?, ?, ?)";

        try (PreparedStatement ps =
                 connection.prepareStatement(sql)) {

            ps.setString(1, team.getTeamName());

            ps.setString(2, team.getDescription());

            ps.setString(3, team.getDepartment());

            ps.setString(4, team.getManagerId());

            ps.setString(5, team.getStatus());

            int result = ps.executeUpdate();

            return result > 0;

        } catch (Exception e) {

            e.printStackTrace();

        }

        return false;
    }


    // ==============================
    // GET ALL TEAMS
    // ==============================

    public List<Team> getAllTeams() {

        List<Team> teams = new ArrayList<>();

        String sql =
            "SELECT t.id, " +
            "t.team_id, " +
            "t.team_name, " +
            "t.description, " +
            "t.department, " +
            "t.manager_id, " +
            "t.status, " +
            "t.created_at, " +
            "t.updated_at, " +
            "m.name AS manager_name, " +
            "m.email AS manager_email, " +
            "m.phone AS manager_phone " +
            "FROM teams t " +
            "LEFT JOIN managers m " +
            "ON t.manager_id = m.employee_id " +
            "ORDER BY t.id DESC";

        try (PreparedStatement ps =
                 connection.prepareStatement(sql);

             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {

                Team team = new Team();

                team.setId(
                    rs.getInt("id")
                );

                team.setTeamId(
                    rs.getString("team_id")
                );

                team.setTeamName(
                    rs.getString("team_name")
                );

                team.setDescription(
                    rs.getString("description")
                );

                team.setDepartment(
                    rs.getString("department")
                );

                // Manager ID
                team.setManagerId(
                    rs.getString("manager_id")
                );

                // Manager Name
                team.setManagerName(
                    rs.getString("manager_name")
                );

                // Manager Email
                team.setManagerEmail(
                    rs.getString("manager_email")
                );

                // Manager Phone
                team.setManagerPhone(
                    rs.getString("manager_phone")
                );

                team.setStatus(
                    rs.getString("status")
                );

                team.setCreatedAt(
                    rs.getString("created_at")
                );

                team.setUpdatedAt(
                    rs.getString("updated_at")
                );

                teams.add(team);
            }

        } catch (Exception e) {

            e.printStackTrace();

        }

        return teams;
    }


    // ==============================
    // GET TEAM BY ID
    // ==============================

    public Team getTeamById(int id) {

        String sql =
            "SELECT t.id, " +
            "t.team_id, " +
            "t.team_name, " +
            "t.description, " +
            "t.department, " +
            "t.manager_id, " +
            "t.status, " +
            "t.created_at, " +
            "t.updated_at, " +
            "m.name AS manager_name, " +
            "m.email AS manager_email, " +
            "m.phone AS manager_phone " +
            "FROM teams t " +
            "LEFT JOIN managers m " +
            "ON t.manager_id = m.employee_id " +
            "WHERE t.id = ?";

        try (PreparedStatement ps =
                 connection.prepareStatement(sql)) {

            ps.setInt(1, id);

            ResultSet rs = ps.executeQuery();

            if (rs.next()) {

                Team team = new Team();

                team.setId(
                    rs.getInt("id")
                );

                team.setTeamId(
                    rs.getString("team_id")
                );

                team.setTeamName(
                    rs.getString("team_name")
                );

                team.setDescription(
                    rs.getString("description")
                );

                team.setDepartment(
                    rs.getString("department")
                );

                team.setManagerId(
                    rs.getString("manager_id")
                );

                team.setManagerName(
                    rs.getString("manager_name")
                );

                team.setManagerEmail(
                    rs.getString("manager_email")
                );

                team.setManagerPhone(
                    rs.getString("manager_phone")
                );

                team.setStatus(
                    rs.getString("status")
                );

                team.setCreatedAt(
                    rs.getString("created_at")
                );

                team.setUpdatedAt(
                    rs.getString("updated_at")
                );

                return team;
            }

        } catch (Exception e) {

            e.printStackTrace();

        }

        return null;
    }


    // ==============================
    // UPDATE TEAM
    // ==============================

    public boolean updateTeam(Team team) {

        String sql =
            "UPDATE teams SET " +
            "team_name = ?, " +
            "description = ?, " +
            "department = ?, " +
            "manager_id = ?, " +
            "status = ? " +
            "WHERE id = ?";

        try (PreparedStatement ps =
                 connection.prepareStatement(sql)) {

            ps.setString(1, team.getTeamName());

            ps.setString(2, team.getDescription());

            ps.setString(3, team.getDepartment());

            ps.setString(4, team.getManagerId());

            ps.setString(5, team.getStatus());

            ps.setInt(6, team.getId());

            int result = ps.executeUpdate();

            return result > 0;

        } catch (Exception e) {

            e.printStackTrace();

        }

        return false;
    }


    // ==============================
    // DEACTIVATE TEAM
    // ==============================

    public boolean deactivateTeam(int id) {

        String sql =
            "UPDATE teams " +
            "SET status = 'INACTIVE' " +
            "WHERE id = ?";

        try (PreparedStatement ps =
                 connection.prepareStatement(sql)) {

            ps.setInt(1, id);

            return ps.executeUpdate() > 0;

        } catch (Exception e) {

            e.printStackTrace();

        }

        return false;
    }
}