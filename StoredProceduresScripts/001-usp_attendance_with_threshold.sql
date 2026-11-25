/*
Date        : 25th November 2026
Assessment  : D1
Description : Return students below an attendance threshold
              for a specific offering and date range.
*/

CREATE OR ALTER PROCEDURE dbo.usp_attendance_with_thresholds
    @OfferingID INT,
    @StartDate DATE,
    @EndDate DATE,
    @AttendanceThreshold DECIMAL(5,2)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate parameters
    IF @StartDate > @EndDate
    BEGIN
        THROW 50001, 'Start date cannot be later than end date.', 1;
    END;

    IF @AttendanceThreshold < 0 OR @AttendanceThreshold > 100
    BEGIN
        THROW 50002, 'Attendance threshold must be between 0 and 100.', 1;
    END;

    ;WITH cte_session_attendance AS
    (
        -- Establish one record per student/session
        SELECT
            ae.StudentID,
            ae.OfferingID,
            ae.SessionDate,
            MAX(
                CASE
                    WHEN ae.AttendanceStatus IN ('Present', 'Late')
                    THEN 1
                    ELSE 0
                END
            ) AS Attended
        FROM mock.AttendanceEvent AS ae
        WHERE ae.OfferingID = @OfferingID
          AND ae.SessionDate >= @StartDate
          AND ae.SessionDate < DATEADD(DAY, 1, @EndDate)
        GROUP BY
            ae.StudentID,
            ae.OfferingID,
            ae.SessionDate
    ),
    cte_attendance_summary AS
    (
        -- Calculate attendance totals and percentage
        SELECT
            sa.StudentID,
            sa.OfferingID,
            COUNT(*) AS PossibleAttendances,
            SUM(sa.Attended) AS AttendanceCount,
            CAST(
                SUM(sa.Attended) * 100.0 / NULLIF(COUNT(*), 0)
                AS DECIMAL(5,2)
            ) AS AttendanceRate
        FROM cte_session_attendance AS sa
        GROUP BY
            sa.StudentID,
            sa.OfferingID
    )
    SELECT
        StudentID,
        OfferingID,
        PossibleAttendances,
        AttendanceCount,
        AttendanceRate
    FROM cte_attendance_summary
    WHERE AttendanceRate < @AttendanceThreshold
    ORDER BY AttendanceRate ASC, StudentID;
END
GO

/*
EXEC dbo.usp_attendance_with_threshold
    @OfferingID = 1001,
    @StartDate = '20251001',
    @EndDate = '20251031',
    @AttendanceThreshold = 90.00;

*/