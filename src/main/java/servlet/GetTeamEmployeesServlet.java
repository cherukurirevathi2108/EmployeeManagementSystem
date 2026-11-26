package servlet;

import java.io.IOException;
import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import model.DBcConnection;

@WebServlet("/GetTeamEmployeesServlet")
public class GetTeamEmployeesServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doGet(HttpServletRequest request,
                          HttpServletResponse response)
            throws ServletException, IOException {

        response.setContentType("text/html;charset=UTF-8");

        PrintWriter out = response.getWriter();

        String teamId = request.getParameter("teamId");

        if (teamId == null || teamId.trim().isEmpty()) {
            out.println("<option value=''>Select Team First</option>");
            return;
        }

        Connection con = null;
        PreparedStatement ps = null;
        ResultSet rs = null;

        try {

            con = DBcConnection.getConnection();

            if (con == null) {
                out.println(
                    "<option value=''>Database connection failed</option>"
                );
                return;
            }

            String sql =
                "SELECT DISTINCT " +
                "e.employee_id, " +
                "e.name " +
                "FROM team_members tm " +
                "JOIN employees e " +
                "ON tm.employee_id = e.employee_id " +
                "WHERE tm.team_id = ? " +
                "AND tm.status = 'ACTIVE' " +
                "AND e.status = 'ACTIVE' " +
                "ORDER BY e.name";

            ps = con.prepareStatement(sql);

            // TEAM001, TEAM002...
            ps.setString(1, teamId);

            rs = ps.executeQuery();

            boolean found = false;

            while (rs.next()) {

                found = true;

                String employeeId =
                    rs.getString("employee_id");

                String employeeName =
                    rs.getString("name");

                out.println(
                    "<option value=\"" +
                    employeeId +
                    "\">" +
                    employeeId +
                    " - " +
                    employeeName +
                    "</option>"
                );
            }

            if (!found) {

                out.println(
                    "<option value=''>No employees in this team</option>"
                );
            }

        } catch (Exception e) {

            e.printStackTrace();

            out.println(
                "<option value=''>Error loading employees</option>"
            );

        } finally {

            try {
                if (rs != null) rs.close();
            } catch (Exception e) {}

            try {
                if (ps != null) ps.close();
            } catch (Exception e) {}

            try {
                if (con != null) con.close();
            } catch (Exception e) {}
        }
    }
}