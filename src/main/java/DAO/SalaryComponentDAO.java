package DAO;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

import model.DBcConnection;
import model.SalaryComponent;

public class SalaryComponentDAO {

    public int addComponent(SalaryComponent component)
            throws SQLException {

        validateComponent(component);

        String sql =
                "INSERT INTO salary_components " +
                "(salary_structure_id, component_name, component_type, " +
                "calculation_type, amount) VALUES (?, ?, ?, ?, ?)";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(
                     sql, PreparedStatement.RETURN_GENERATED_KEYS)) {

            ps.setInt(1, component.getSalaryStructureId());
            ps.setString(2, component.getComponentName().trim());
            ps.setString(3, component.getComponentType().toUpperCase());
            ps.setString(4, component.getCalculationType().toUpperCase());
            ps.setBigDecimal(5, component.getAmount());

            if (ps.executeUpdate() == 0) {
                throw new SQLException("Unable to save salary component.");
            }

            try (ResultSet keys = ps.getGeneratedKeys()) {
                if (keys.next()) {
                    return keys.getInt(1);
                }
            }
        }

        throw new SQLException("Unable to retrieve component ID.");
    }

    // Used inside a transaction (shares the caller's connection).
    public int addComponent(Connection con, SalaryComponent component)
            throws SQLException {

        validateComponent(component);

        String sql =
                "INSERT INTO salary_components " +
                "(salary_structure_id, component_name, component_type, " +
                "calculation_type, amount) VALUES (?, ?, ?, ?, ?)";

        try (PreparedStatement ps = con.prepareStatement(
                sql, PreparedStatement.RETURN_GENERATED_KEYS)) {

            ps.setInt(1, component.getSalaryStructureId());
            ps.setString(2, component.getComponentName().trim());
            ps.setString(3, component.getComponentType().toUpperCase());
            ps.setString(4, component.getCalculationType().toUpperCase());
            ps.setBigDecimal(5, component.getAmount());

            if (ps.executeUpdate() == 0) {
                throw new SQLException("Unable to save salary component.");
            }

            try (ResultSet keys = ps.getGeneratedKeys()) {
                if (keys.next()) {
                    return keys.getInt(1);
                }
            }
        }

        throw new SQLException("Unable to retrieve component ID.");
    }

    public List<SalaryComponent> getComponentsByStructureId(
            int salaryStructureId) throws SQLException {

        List<SalaryComponent> list = new ArrayList<>();

        String sql =
                "SELECT id, salary_structure_id, component_name, " +
                "component_type, calculation_type, amount " +
                "FROM salary_components " +
                "WHERE salary_structure_id = ? ORDER BY id";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setInt(1, salaryStructureId);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    SalaryComponent component = new SalaryComponent();

                    component.setId(rs.getInt("id"));
                    component.setSalaryStructureId(
                            rs.getInt("salary_structure_id"));
                    component.setComponentName(
                            rs.getString("component_name"));
                    component.setComponentType(
                            rs.getString("component_type"));
                    component.setCalculationType(
                            rs.getString("calculation_type"));
                    component.setAmount(rs.getBigDecimal("amount"));

                    list.add(component);
                }
            }
        }

        return list;
    }
    public boolean updateComponent(SalaryComponent component)
            throws SQLException {

        validateComponent(component);

        if (component.getId() <= 0) {
            throw new IllegalArgumentException("Invalid component ID.");
        }

        String sql =
                "UPDATE salary_components SET " +
                "component_name = ?, component_type = ?, " +
                "calculation_type = ?, amount = ? " +
                "WHERE id = ? AND salary_structure_id = ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, component.getComponentName().trim());
            ps.setString(2, component.getComponentType().toUpperCase());
            ps.setString(3, component.getCalculationType().toUpperCase());
            ps.setBigDecimal(4, component.getAmount());
            ps.setInt(5, component.getId());
            ps.setInt(6, component.getSalaryStructureId());

            return ps.executeUpdate() > 0;
        }
    }

    public boolean deleteComponent(int componentId)
            throws SQLException {

        if (componentId <= 0) {
            throw new IllegalArgumentException("Invalid component ID.");
        }

        String sql = "DELETE FROM salary_components WHERE id = ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setInt(1, componentId);

            return ps.executeUpdate() > 0;
        }
    }

    private void validateComponent(SalaryComponent component) {

        if (component == null
                || component.getSalaryStructureId() <= 0
                || component.getComponentName() == null
                || component.getComponentName().trim().isEmpty()
                || component.getComponentType() == null
                || component.getCalculationType() == null
                || component.getAmount() == null
                || component.getAmount().signum() < 0) {

            throw new IllegalArgumentException(
                    "Enter valid component details.");
        }

        String type = component.getComponentType().toUpperCase();
        String calculation =
                component.getCalculationType().toUpperCase();

        if (!type.equals("EARNING") && !type.equals("DEDUCTION")) {
            throw new IllegalArgumentException(
                    "Component type must be EARNING or DEDUCTION.");
        }

        if (!calculation.equals("FIXED")
                && !calculation.equals("PERCENTAGE")) {
            throw new IllegalArgumentException(
                    "Calculation type must be FIXED or PERCENTAGE.");
        }

        if (calculation.equals("PERCENTAGE")
                && component.getAmount().compareTo(
                        new BigDecimal("100")) > 0) {
            throw new IllegalArgumentException(
                    "Percentage cannot exceed 100.");
        }
    }
}