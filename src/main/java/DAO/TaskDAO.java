



package DAO;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

import model.Task;
import model.DBcConnection;

public class TaskDAO {

    // Add one employee's task record, with a shared group ID.
    public boolean addTask(Task task) {
        String sql = "INSERT INTO tasks "
                + "(task_group_id, task_title, description, assigned_to, "
                + "created_by, department, priority, start_date, due_date, "
                + "status, instruction_file) "
                + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, task.getTaskGroupId());
            ps.setString(2, task.getTaskTitle());
            ps.setString(3, task.getDescription());
            ps.setString(4, task.getAssignedTo());
            ps.setString(5, task.getCreatedBy());
            ps.setString(6, task.getDepartment());
            ps.setString(7, task.getPriority());
            ps.setDate(8, task.getStartDate());
            ps.setDate(9, task.getDueDate());
            ps.setString(10, task.getStatus());
            ps.setString(11, task.getInstructionFile());

            return ps.executeUpdate() > 0;

        } catch (Exception e) {
            e.printStackTrace();
        }

        return false;
    }

    public List<String[]> getTeamsByManager(String managerId) {
        List<String[]> teams = new ArrayList<>();

        String sql = "SELECT team_id, team_name FROM teams "
                + "WHERE manager_id = ? AND status = 'ACTIVE' "
                + "ORDER BY team_name";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, managerId);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    teams.add(new String[] {
                        rs.getString("team_id"),
                        rs.getString("team_name")
                    });
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        return teams;
    }

    public List<String[]> getEmployeesByManagerTeam(
            String teamId, String managerId) {

        List<String[]> employees = new ArrayList<>();

        String sql = "SELECT DISTINCT e.employee_id, e.name "
                + "FROM team_members tm "
                + "JOIN employees e ON e.employee_id = tm.employee_id "
                + "JOIN teams t ON t.team_id = tm.team_id "
                + "WHERE tm.team_id = ? AND t.manager_id = ? "
                + "AND t.status = 'ACTIVE' "
                + "AND tm.status = 'ACTIVE' "
                + "AND e.status = 'ACTIVE' "
                + "ORDER BY e.name";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, teamId);
            ps.setString(2, managerId);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    employees.add(new String[] {
                        rs.getString("employee_id"),
                        rs.getString("name")
                    });
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        return employees;
    }

    public boolean isEmployeeInManagerTeam(
            String teamId, String employeeId, String managerId) {

        String sql = "SELECT 1 FROM team_members tm "
                + "JOIN teams t ON t.team_id = tm.team_id "
                + "JOIN employees e ON e.employee_id = tm.employee_id "
                + "WHERE tm.team_id = ? AND tm.employee_id = ? "
                + "AND t.manager_id = ? AND t.status = 'ACTIVE' "
                + "AND tm.status = 'ACTIVE' "
                + "AND e.status = 'ACTIVE' LIMIT 1";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, teamId);
            ps.setString(2, employeeId);
            ps.setString(3, managerId);

            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        return false;
    }

    private String getTaskQuery() {
        return "SELECT t.*, m.name AS created_by_name "
                + "FROM tasks t "
                + "LEFT JOIN managers m "
                + "ON t.created_by = m.employee_id ";
    }

    public List<Task> getAllTasks() {
        List<Task> tasks = new ArrayList<>();

        String sql = getTaskQuery() + "ORDER BY t.id DESC";

        try (Connection con = DBcConnection.getConnection();
             Statement st = con.createStatement();
             ResultSet rs = st.executeQuery(sql)) {

            while (rs.next()) {
                tasks.add(extractTask(rs));
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        return tasks;
    }

    public List<Task> getTasksByEmployee(String employeeId) {
        List<Task> tasks = new ArrayList<>();

        String sql = getTaskQuery()
                + "WHERE t.assigned_to = ? ORDER BY t.due_date ASC";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, employeeId);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    tasks.add(extractTask(rs));
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        return tasks;
    }

    public List<Task> getTasksByManager(String managerId) {
        List<Task> tasks = new ArrayList<>();

        String sql = getTaskQuery()
                + "WHERE t.created_by = ? ORDER BY t.id DESC";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, managerId);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    tasks.add(extractTask(rs));
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        return tasks;
    }

    // Fetch one employee's task record.
    public Task getTaskById(int id) {
        String sql = getTaskQuery() + "WHERE t.id = ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setInt(1, id);

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return extractTask(rs);
                }
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        return null;
    }

    public boolean isAssignedToEmployee(int taskId, String employeeId) {
        String sql = "SELECT id FROM tasks "
                + "WHERE id = ? AND assigned_to = ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setInt(1, taskId);
            ps.setString(2, employeeId);

            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        return false;
    }

    public boolean isCreatedByManager(int taskId, String managerId) {
        String sql = "SELECT id FROM tasks "
                + "WHERE id = ? AND created_by = ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setInt(1, taskId);
            ps.setString(2, managerId);

            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();
            }

        } catch (Exception e) {
            e.printStackTrace();
        }

        return false;
    }

    public boolean updateInstructionFile(
            int taskId, String managerId, String fileName) {

        String sql = "UPDATE tasks SET instruction_file = ? "
                + "WHERE id = ? AND created_by = ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, fileName);
            ps.setInt(2, taskId);
            ps.setString(3, managerId);

            return ps.executeUpdate() > 0;

        } catch (Exception e) {
            e.printStackTrace();
        }

        return false;
    }

    /*
     * Employee can submit proof files more than once.
     * New file names are appended with | so existing proofs remain.
     * Only the selected employee's task record is updated.
     */
    public boolean submitWork(
            int taskId,
            String employeeId,
            String proofFile,
            String comment) {

        String sql = "UPDATE tasks SET "
                + "work_proof_file = CASE "
                + "WHEN ? IS NULL OR ? = '' THEN work_proof_file "
                + "WHEN work_proof_file IS NULL OR work_proof_file = '' "
                + "THEN ? "
                + "ELSE CONCAT(work_proof_file, '|', ?) "
                + "END, "
                + "employee_comment = ?, "
                + "status = CASE "
                + "WHEN status IS NULL OR status = '' "
                + "OR status = 'ASSIGNED' OR status = 'PENDING' "
                + "THEN 'IN_PROGRESS' ELSE status END "
                + "WHERE id = ? AND assigned_to = ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, proofFile);
            ps.setString(2, proofFile);
            ps.setString(3, proofFile);
            ps.setString(4, proofFile);
            ps.setString(5, comment);
            ps.setInt(6, taskId);
            ps.setString(7, employeeId);

            return ps.executeUpdate() > 0;

        } catch (Exception e) {
            e.printStackTrace();
        }

        return false;
    }

    /*
     * Review only the selected employee's task row.
     */
    public boolean reviewTask(
            int taskId,
            String managerId,
            String status,
            int rating,
            String remarks) {

        if (!"IN_PROGRESS".equals(status)
                && !"COMPLETED".equals(status)
                && !"REJECTED".equals(status)) {
            return false;
        }

        if (rating < 1 || rating > 5) {
            return false;
        }

        String sql = "UPDATE tasks SET status = ?, manager_rating = ?, "
                + "manager_remarks = ?, reviewed_by = ?, "
                + "reviewed_at = CURRENT_TIMESTAMP "
                + "WHERE id = ? AND created_by = ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, status);
            ps.setInt(2, rating);
            ps.setString(3, remarks);
            ps.setString(4, managerId);
            ps.setInt(5, taskId);
            ps.setString(6, managerId);

            return ps.executeUpdate() > 0;

        } catch (Exception e) {
            e.printStackTrace();
        }

        return false;
    }

    public boolean updateTask(Task task) {
        String sql = "UPDATE tasks SET task_title = ?, description = ?, "
                + "assigned_to = ?, department = ?, priority = ?, "
                + "start_date = ?, due_date = ?, status = ?, "
                + "employee_comment = ? WHERE id = ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, task.getTaskTitle());
            ps.setString(2, task.getDescription());
            ps.setString(3, task.getAssignedTo());
            ps.setString(4, task.getDepartment());
            ps.setString(5, task.getPriority());
            ps.setDate(6, task.getStartDate());
            ps.setDate(7, task.getDueDate());
            ps.setString(8, task.getStatus());
            ps.setString(9, task.getEmployeeComment());
            ps.setInt(10, task.getId());

            return ps.executeUpdate() > 0;

        } catch (Exception e) {
            e.printStackTrace();
        }

        return false;
    }

    public boolean updateTaskByManager(Task task, String managerId) {
        String sql = "UPDATE tasks SET task_title = ?, description = ?, "
                + "assigned_to = ?, department = ?, priority = ?, "
                + "start_date = ?, due_date = ? "
                + "WHERE id = ? AND created_by = ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, task.getTaskTitle());
            ps.setString(2, task.getDescription());
            ps.setString(3, task.getAssignedTo());
            ps.setString(4, task.getDepartment());
            ps.setString(5, task.getPriority());
            ps.setDate(6, task.getStartDate());
            ps.setDate(7, task.getDueDate());
            ps.setInt(8, task.getId());
            ps.setString(9, managerId);

            return ps.executeUpdate() > 0;

        } catch (Exception e) {
            e.printStackTrace();
        }

        return false;
    }

    public boolean updateTaskProgress(
            int taskId,
            String employeeId,
            String status,
            String comment) {

        if (!"IN_PROGRESS".equals(status)) {
            return false;
        }

        String sql = "UPDATE tasks SET status = 'IN_PROGRESS', "
                + "employee_comment = ? "
                + "WHERE id = ? AND assigned_to = ? "
                + "AND (status IS NULL OR status NOT IN "
                + "('COMPLETED', 'REJECTED'))";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, comment);
            ps.setInt(2, taskId);
            ps.setString(3, employeeId);

            return ps.executeUpdate() > 0;

        } catch (Exception e) {
            e.printStackTrace();
        }

        return false;
    }

    public boolean deleteTask(int id) {
        String sql = "DELETE FROM tasks WHERE id = ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setInt(1, id);

            return ps.executeUpdate() > 0;

        } catch (Exception e) {
            e.printStackTrace();
        }

        return false;
    }

    public boolean deleteTaskByManager(int id, String managerId) {
        String sql = "DELETE FROM tasks WHERE id = ? AND created_by = ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setInt(1, id);
            ps.setString(2, managerId);

            return ps.executeUpdate() > 0;

        } catch (Exception e) {
            e.printStackTrace();
        }

        return false;
    }

    // Map database columns to the Task model.
    private Task extractTask(ResultSet rs) throws Exception {
        Task task = new Task();

        task.setId(rs.getInt("id"));
        task.setTaskGroupId(rs.getString("task_group_id"));

        task.setTaskTitle(rs.getString("task_title"));
        task.setDescription(rs.getString("description"));
        task.setAssignedTo(rs.getString("assigned_to"));
        task.setCreatedBy(rs.getString("created_by"));
        task.setCreatedByName(rs.getString("created_by_name"));
        task.setDepartment(rs.getString("department"));
        task.setPriority(rs.getString("priority"));

        task.setStartDate(rs.getDate("start_date"));
        task.setDueDate(rs.getDate("due_date"));

        task.setStatus(rs.getString("status"));
        task.setEmployeeComment(rs.getString("employee_comment"));

        task.setCreatedAt(rs.getTimestamp("created_at"));
        task.setUpdatedAt(rs.getTimestamp("updated_at"));

        task.setInstructionFile(rs.getString("instruction_file"));
        task.setWorkProofFile(rs.getString("work_proof_file"));

        int rating = rs.getInt("manager_rating");
        task.setManagerRating(rs.wasNull() ? null : rating);

        task.setManagerRemarks(rs.getString("manager_remarks"));
        task.setReviewedBy(rs.getString("reviewed_by"));
        task.setReviewedAt(rs.getTimestamp("reviewed_at"));

        return task;
    }
}
