<%@ page import="java.sql.*" %>
<%@ page import="model.DBcConnection" %>

<!DOCTYPE html>
<html>

<head>

    <title>Create Team</title>

    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <style>

        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            min-height: 100vh;
            font-family: Arial, Helvetica, sans-serif;
            background: linear-gradient(
                135deg,
                #eef2ff 0%,
                #f8f5ff 45%,
                #eef7ff 100%
            );
            color: #1f2937;
        }

        /* =========================
           HEADER
        ========================= */

        .top-header {
            width: 100%;
            padding: 18px 45px;
            background: linear-gradient(
                135deg,
                #4f46e5,
                #6d28d9,
                #7c3aed
            );
            color: white;
            display: flex;
            align-items: center;
            justify-content: space-between;
            box-shadow:
                0 4px 18px rgba(79, 70, 229, 0.25);
        }

        .brand {
            font-size: 22px;
            font-weight: bold;
            letter-spacing: 0.3px;
        }

        .brand span {
            opacity: 0.8;
            font-size: 14px;
            font-weight: normal;
            margin-left: 8px;
        }

        /* =========================
           MAIN
        ========================= */

        .main-wrapper {
            width: 100%;
            padding: 45px 20px;
        }

        /* =========================
           FORM CARD
        ========================= */

        .container {
            width: 620px;
            max-width: 100%;
            margin: 0 auto;
            background: rgba(255, 255, 255, 0.97);
            padding: 38px 42px;
            border-radius: 18px;
            box-shadow:
                0 15px 45px rgba(79, 70, 229, 0.12),
                0 3px 12px rgba(0, 0, 0, 0.06);
            border: 1px solid #e5e7eb;
        }

        /* =========================
           TITLE
        ========================= */

        .title-section {
            text-align: center;
            margin-bottom: 30px;
        }

        .icon-box {
            width: 60px;
            height: 60px;
            margin: 0 auto 14px;
            border-radius: 16px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 15px;
            font-weight: bold;
            letter-spacing: 1px;
            background: linear-gradient(
                135deg,
                #4f46e5,
                #7c3aed
            );
            color: white;
            box-shadow:
                0 8px 20px rgba(79, 70, 229, 0.25);
        }

        h2 {
            margin: 0;
            color: #1e1b4b;
            font-size: 27px;
        }

        .subtitle {
            margin-top: 8px;
            color: #6b7280;
            font-size: 14px;
        }

        /* =========================
           MESSAGE
        ========================= */

        .message {
            text-align: center;
            padding: 12px 15px;
            margin-bottom: 22px;
            border-radius: 9px;
            background: #fef2f2;
            color: #dc2626;
            font-size: 14px;
            font-weight: 600;
            border: 1px solid #fecaca;
        }

        .message.success {
            background: #ecfdf5;
            color: #059669;
            border: 1px solid #a7f3d0;
        }

        /* =========================
           FORM GROUP
        ========================= */

        .form-group {
            margin-bottom: 20px;
        }

        label {
            display: block;
            margin-bottom: 8px;
            font-size: 14px;
            font-weight: 600;
            color: #374151;
        }

        .required {
            color: #ef4444;
        }

        /* =========================
           INPUTS
        ========================= */

        input,
        select,
        textarea {
            width: 100%;
            padding: 13px 14px;
            border: 1px solid #d1d5db;
            border-radius: 9px;
            font-size: 14px;
            background: #ffffff;
            color: #1f2937;
            outline: none;
            transition:
                border-color 0.2s,
                box-shadow 0.2s,
                background 0.2s;
        }

        input:hover,
        select:hover,
        textarea:hover {
            border-color: #a5b4fc;
        }

        input:focus,
        select:focus,
        textarea:focus {
            border-color: #6366f1;
            background: #fafaff;
            box-shadow:
                0 0 0 3px rgba(99, 102, 241, 0.12);
        }

        textarea {
            resize: vertical;
            min-height: 120px;
            line-height: 1.5;
        }

        /* =========================
           NOTE
        ========================= */

        .note {
            margin-top: 6px;
            font-size: 12px;
            color: #6b7280;
        }

        /* =========================
           MANAGER INFO
        ========================= */

        .manager-info {
            display: flex;
            align-items: center;
            gap: 8px;
            margin-top: 7px;
            font-size: 12px;
            color: #6b7280;
        }

        .manager-dot {
            width: 7px;
            height: 7px;
            background: #22c55e;
            border-radius: 50%;
        }

        /* =========================
           CREATE BUTTON
        ========================= */

        button {
            width: 100%;
            margin-top: 10px;
            padding: 14px;
            border: none;
            border-radius: 10px;
            background: linear-gradient(
                135deg,
                #4f46e5,
                #7c3aed
            );
            color: white;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            box-shadow:
                0 8px 18px rgba(79, 70, 229, 0.22);
            transition:
                transform 0.2s,
                box-shadow 0.2s,
                opacity 0.2s;
        }

        button:hover {
            transform: translateY(-2px);
            box-shadow:
                0 12px 24px rgba(79, 70, 229, 0.30);
        }

        button:active {
            transform: translateY(0);
        }

        /* =========================
           BACK BUTTON
        ========================= */

        .back {
            display: block;
            text-align: center;
            margin-top: 20px;
            padding: 11px;
            border-radius: 9px;
            color: #4f46e5;
            background: #f5f3ff;
            text-decoration: none;
            font-size: 14px;
            font-weight: 600;
            transition: 0.2s;
        }

        .back:hover {
            background: #ede9fe;
            color: #4338ca;
        }

        /* =========================
           RESPONSIVE
        ========================= */

        @media (max-width: 700px) {

            .top-header {
                padding: 16px 20px;
            }

            .brand {
                font-size: 18px;
            }

            .brand span {
                display: none;
            }

            .main-wrapper {
                padding: 25px 15px;
            }

            .container {
                padding: 28px 22px;
            }

            h2 {
                font-size: 23px;
            }

        }

    </style>

    <script>

        function validateForm() {

            var teamName =
                document.getElementById("teamName").value;

            var department =
                document.getElementById("department").value;

            var manager =
                document.getElementById("managerId").value;

            var description =
                document.getElementById("description").value;

            /* Team Name */

            if (teamName.trim() === "") {

                alert("Team Name is required");

                document.getElementById("teamName").focus();

                return false;
            }

            /* Department */

            if (department === "") {

                alert("Department must be selected");

                document.getElementById("department").focus();

                return false;
            }

            /* Manager */

            if (manager === "") {

                alert("Team Manager must be selected");

                document.getElementById("managerId").focus();

                return false;
            }

            /* Description */

            if (description.length > 500) {

                alert(
                    "Description should not exceed 500 characters"
                );

                document.getElementById("description").focus();

                return false;
            }

            return true;
        }

    </script>

</head>


<body>

    <!-- =========================
         HEADER
    ========================= -->

    <div class="top-header">

        <div class="brand">

            Employee Management System

            <span>
                Team Management
            </span>

        </div>

    </div>


    <!-- =========================
         MAIN
    ========================= -->

    <div class="main-wrapper">

        <div class="container">


            <!-- =========================
                 TITLE
            ========================= -->

            <div class="title-section">

                <div class="icon-box">
                    TEAM
                </div>

                <h2>
                    Create New Team
                </h2>

                <div class="subtitle">
                    Create a team and assign a manager
                </div>

            </div>


            <!-- =========================
                 MESSAGE
            ========================= -->

            <%

                String message =
                    request.getParameter("message");

                String type =
                    request.getParameter("type");


                if (message != null) {

            %>

                <div class="message
                    <%= "success".equals(type)
                        ? "success"
                        : "" %>">

                    <%= message %>

                </div>

            <%

                }

            %>


            <!-- =========================
                 FORM
            ========================= -->

            <form
                action="CreateTeamServlet"
                method="post"
                onsubmit="return validateForm()">


                <!-- TEAM NAME -->

                <div class="form-group">

                    <label for="teamName">

                        Team Name

                        <span class="required">
                            *
                        </span>

                    </label>


                    <input
                        type="text"
                        id="teamName"
                        name="teamName"
                        maxlength="100"
                        placeholder="Enter team name"
                        autocomplete="off">


                    <div class="note">
                        Team name is required and must be unique.
                    </div>

                </div>


                <!-- DEPARTMENT -->

                <div class="form-group">

                    <label for="department">

                        Department

                        <span class="required">
                            *
                        </span>

                    </label>


                    <select
                        id="department"
                        name="department">

                        <option value="">
                            -- Select Department --
                        </option>

                        <option value="IT">
                            IT
                        </option>

                        <option value="HR">
                            HR
                        </option>

                        <option value="Finance">
                            Finance
                        </option>

                        <option value="Marketing">
                            Marketing
                        </option>

                        <option value="Operations">
                            Operations
                        </option>

                        <option value="Sales">
                            Sales
                        </option>

                    </select>

                </div>


                <!-- TEAM MANAGER -->

                <div class="form-group">

                    <label for="managerId">

                        Team Manager

                        <span class="required">
                            *
                        </span>

                    </label>


                    <select
                        id="managerId"
                        name="managerId">

                        <option value="">
                            -- Select Team Manager --
                        </option>


                        <%

                            Connection con = null;
                            PreparedStatement ps = null;
                            ResultSet rs = null;


                            try {

                                con =
                                    DBcConnection.getConnection();


                                /*
                                 * MANAGERS ARE LOADED
                                 * FROM MANAGERS TABLE
                                 */

                                String sql =
                                    "SELECT employee_id, name " +
                                    "FROM managers " +
                                    "WHERE status = 'ACTIVE' " +
                                    "ORDER BY name";


                                ps =
                                    con.prepareStatement(sql);


                                rs =
                                    ps.executeQuery();


                                while (rs.next()) {

                        %>


                            <option
                                value="<%= rs.getString("employee_id") %>">

                                <%= rs.getString("employee_id") %>
                                -
                                <%= rs.getString("name") %>

                            </option>


                        <%

                                }

                            }

                            catch (Exception e) {

                                e.printStackTrace();

                            }

                            finally {

                                try {

                                    if (rs != null)
                                        rs.close();

                                } catch (Exception e) {}


                                try {

                                    if (ps != null)
                                        ps.close();

                                } catch (Exception e) {}


                                try {

                                    if (con != null)
                                        con.close();

                                } catch (Exception e) {}

                            }

                        %>


                    </select>


                    <div class="manager-info">

                        <span class="manager-dot"></span>

                        Only active managers are displayed.

                    </div>

                </div>


                <!-- DESCRIPTION -->

                <div class="form-group">

                    <label for="description">

                        Team Description

                    </label>


                    <textarea
                        id="description"
                        name="description"
                        maxlength="500"
                        placeholder="Enter team description"></textarea>


                    <div class="note">
                        Maximum 500 characters.
                    </div>

                </div>


                <!-- CREATE TEAM -->

                <button type="submit">

                    Create Team

                </button>


            </form>


            <!-- BACK -->

            <a
                href="admin_dashbaord.jsp"
                class="back">

                Back to Admin Dashboard

            </a>


        </div>

    </div>

</body>

</html>