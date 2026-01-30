-- ============================================================
-- DripJobs Work Order Customization - Phase 1
-- Stored Procedures
-- ============================================================

-- ============================================================
-- 1. Get Work Order for Editing
-- ============================================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_WorkOrder_GetForEdit]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[usp_WorkOrder_GetForEdit]
GO

CREATE PROCEDURE [dbo].[usp_WorkOrder_GetForEdit]
    @WorkOrderId INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Get Work Order header info
    SELECT
        wo.WorkOrderId,
        wo.ProposalNumber,
        wo.ProposalState,
        wo.CustomerName,
        wo.JobName,
        wo.JobAddress,
        wo.LastModifiedDate,
        wo.LastModifiedBy,
        wo.ProposalId AS OriginalProposalId
    FROM [dbo].[WorkOrders] wo
    WHERE wo.WorkOrderId = @WorkOrderId;

    -- Get Areas/Sections
    SELECT
        wa.AreaId,
        wa.WorkOrderId,
        wa.AreaName,
        wa.CustomAreaName,
        wa.SortOrder
    FROM [dbo].[WorkOrderAreas] wa
    WHERE wa.WorkOrderId = @WorkOrderId
    ORDER BY wa.SortOrder, wa.AreaId;

    -- Get Line Items (include deleted for reference, client will filter)
    SELECT
        li.LineItemId,
        li.AreaId,
        li.ItemName,
        li.ItemType,
        li.ProductName,
        li.Sheen,
        li.Color,
        li.PrepHrs,
        li.WorkingHrs,
        (li.PrepHrs + li.WorkingHrs) AS TotalHrs,
        li.Unit,
        li.Coats,
        li.SortOrder,
        li.IsDeleted,
        li.DeletedDate,
        li.IsModified,
        li.OriginalPrepHrs,
        li.OriginalWorkingHrs,
        li.OriginalUnit,
        li.OriginalCoats
    FROM [dbo].[WorkOrderLineItems] li
    INNER JOIN [dbo].[WorkOrderAreas] wa ON li.AreaId = wa.AreaId
    WHERE wa.WorkOrderId = @WorkOrderId
    ORDER BY wa.SortOrder, wa.AreaId, li.SortOrder, li.LineItemId;
END
GO

-- ============================================================
-- 2. Reorder Line Items within an Area
-- ============================================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_WorkOrder_ReorderLineItems]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[usp_WorkOrder_ReorderLineItems]
GO

CREATE PROCEDURE [dbo].[usp_WorkOrder_ReorderLineItems]
    @WorkOrderId INT,
    @AreaId INT,
    @LineItemIds NVARCHAR(MAX), -- Comma-separated list of line item IDs in new order
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Parse the comma-separated IDs and update sort order
        DECLARE @SortOrder INT = 1;
        DECLARE @LineItemId INT;
        DECLARE @Pos INT;

        WHILE LEN(@LineItemIds) > 0
        BEGIN
            SET @Pos = CHARINDEX(',', @LineItemIds);

            IF @Pos = 0
            BEGIN
                SET @LineItemId = CAST(@LineItemIds AS INT);
                SET @LineItemIds = '';
            END
            ELSE
            BEGIN
                SET @LineItemId = CAST(LEFT(@LineItemIds, @Pos - 1) AS INT);
                SET @LineItemIds = SUBSTRING(@LineItemIds, @Pos + 1, LEN(@LineItemIds) - @Pos);
            END

            -- Update sort order
            UPDATE [dbo].[WorkOrderLineItems]
            SET SortOrder = @SortOrder
            WHERE LineItemId = @LineItemId AND AreaId = @AreaId;

            SET @SortOrder = @SortOrder + 1;
        END

        -- Log the change
        INSERT INTO [dbo].[WorkOrderChangeLog] (WorkOrderId, AreaId, ChangeType, ChangedBy)
        VALUES (@WorkOrderId, @AreaId, 'LineItemReorder', @ModifiedBy);

        -- Update work order modified timestamp
        UPDATE [dbo].[WorkOrders]
        SET LastModifiedDate = GETDATE(), LastModifiedBy = @ModifiedBy
        WHERE WorkOrderId = @WorkOrderId;

        COMMIT TRANSACTION;
        SELECT 1 AS Success, 'Line items reordered successfully' AS Message;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT 0 AS Success, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

-- ============================================================
-- 3. Reorder Areas/Sections
-- ============================================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_WorkOrder_ReorderAreas]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[usp_WorkOrder_ReorderAreas]
GO

CREATE PROCEDURE [dbo].[usp_WorkOrder_ReorderAreas]
    @WorkOrderId INT,
    @AreaIds NVARCHAR(MAX), -- Comma-separated list of area IDs in new order
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Parse the comma-separated IDs and update sort order
        DECLARE @SortOrder INT = 1;
        DECLARE @AreaId INT;
        DECLARE @Pos INT;

        WHILE LEN(@AreaIds) > 0
        BEGIN
            SET @Pos = CHARINDEX(',', @AreaIds);

            IF @Pos = 0
            BEGIN
                SET @AreaId = CAST(@AreaIds AS INT);
                SET @AreaIds = '';
            END
            ELSE
            BEGIN
                SET @AreaId = CAST(LEFT(@AreaIds, @Pos - 1) AS INT);
                SET @AreaIds = SUBSTRING(@AreaIds, @Pos + 1, LEN(@AreaIds) - @Pos);
            END

            -- Update sort order
            UPDATE [dbo].[WorkOrderAreas]
            SET SortOrder = @SortOrder
            WHERE AreaId = @AreaId AND WorkOrderId = @WorkOrderId;

            SET @SortOrder = @SortOrder + 1;
        END

        -- Log the change
        INSERT INTO [dbo].[WorkOrderChangeLog] (WorkOrderId, ChangeType, ChangedBy)
        VALUES (@WorkOrderId, 'AreaReorder', @ModifiedBy);

        -- Update work order modified timestamp
        UPDATE [dbo].[WorkOrders]
        SET LastModifiedDate = GETDATE(), LastModifiedBy = @ModifiedBy
        WHERE WorkOrderId = @WorkOrderId;

        COMMIT TRANSACTION;
        SELECT 1 AS Success, 'Areas reordered successfully' AS Message;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT 0 AS Success, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

-- ============================================================
-- 4. Update Line Item Field
-- ============================================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_WorkOrder_UpdateLineItem]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[usp_WorkOrder_UpdateLineItem]
GO

CREATE PROCEDURE [dbo].[usp_WorkOrder_UpdateLineItem]
    @WorkOrderId INT,
    @LineItemId INT,
    @FieldName NVARCHAR(50),
    @NewValue NVARCHAR(MAX),
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @OldValue NVARCHAR(MAX);
        DECLARE @AreaId INT;

        -- Get current value and area ID
        SELECT
            @AreaId = li.AreaId,
            @OldValue = CASE @FieldName
                WHEN 'PrepHrs' THEN CAST(li.PrepHrs AS NVARCHAR(MAX))
                WHEN 'WorkingHrs' THEN CAST(li.WorkingHrs AS NVARCHAR(MAX))
                WHEN 'Unit' THEN li.Unit
                WHEN 'Coats' THEN CAST(li.Coats AS NVARCHAR(MAX))
            END
        FROM [dbo].[WorkOrderLineItems] li
        INNER JOIN [dbo].[WorkOrderAreas] wa ON li.AreaId = wa.AreaId
        WHERE li.LineItemId = @LineItemId AND wa.WorkOrderId = @WorkOrderId;

        -- Update the field
        IF @FieldName = 'PrepHrs'
            UPDATE [dbo].[WorkOrderLineItems]
            SET PrepHrs = CAST(@NewValue AS DECIMAL(10,2)), IsModified = 1
            WHERE LineItemId = @LineItemId;
        ELSE IF @FieldName = 'WorkingHrs'
            UPDATE [dbo].[WorkOrderLineItems]
            SET WorkingHrs = CAST(@NewValue AS DECIMAL(10,2)), IsModified = 1
            WHERE LineItemId = @LineItemId;
        ELSE IF @FieldName = 'Unit'
            UPDATE [dbo].[WorkOrderLineItems]
            SET Unit = @NewValue, IsModified = 1
            WHERE LineItemId = @LineItemId;
        ELSE IF @FieldName = 'Coats'
            UPDATE [dbo].[WorkOrderLineItems]
            SET Coats = CAST(@NewValue AS INT), IsModified = 1
            WHERE LineItemId = @LineItemId;

        -- Log the change
        INSERT INTO [dbo].[WorkOrderChangeLog]
            (WorkOrderId, AreaId, LineItemId, ChangeType, FieldName, OldValue, NewValue, ChangedBy)
        VALUES
            (@WorkOrderId, @AreaId, @LineItemId, 'LineItemUpdate', @FieldName, @OldValue, @NewValue, @ModifiedBy);

        -- Update work order modified timestamp
        UPDATE [dbo].[WorkOrders]
        SET LastModifiedDate = GETDATE(), LastModifiedBy = @ModifiedBy
        WHERE WorkOrderId = @WorkOrderId;

        COMMIT TRANSACTION;

        -- Return updated totals
        SELECT
            1 AS Success,
            'Field updated successfully' AS Message,
            li.PrepHrs,
            li.WorkingHrs,
            (li.PrepHrs + li.WorkingHrs) AS TotalHrs,
            li.Unit,
            li.Coats,
            @AreaId AS AreaId
        FROM [dbo].[WorkOrderLineItems] li
        WHERE li.LineItemId = @LineItemId;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT 0 AS Success, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

-- ============================================================
-- 5. Delete (Soft Delete) Line Item
-- ============================================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_WorkOrder_DeleteLineItem]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[usp_WorkOrder_DeleteLineItem]
GO

CREATE PROCEDURE [dbo].[usp_WorkOrder_DeleteLineItem]
    @WorkOrderId INT,
    @LineItemId INT,
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @AreaId INT;
        DECLARE @ItemName NVARCHAR(200);

        -- Get line item info
        SELECT @AreaId = li.AreaId, @ItemName = li.ItemName
        FROM [dbo].[WorkOrderLineItems] li
        INNER JOIN [dbo].[WorkOrderAreas] wa ON li.AreaId = wa.AreaId
        WHERE li.LineItemId = @LineItemId AND wa.WorkOrderId = @WorkOrderId;

        -- Soft delete the line item
        UPDATE [dbo].[WorkOrderLineItems]
        SET IsDeleted = 1, DeletedDate = GETDATE()
        WHERE LineItemId = @LineItemId;

        -- Log the change
        INSERT INTO [dbo].[WorkOrderChangeLog]
            (WorkOrderId, AreaId, LineItemId, ChangeType, OldValue, ChangedBy)
        VALUES
            (@WorkOrderId, @AreaId, @LineItemId, 'LineItemDelete', @ItemName, @ModifiedBy);

        -- Update work order modified timestamp
        UPDATE [dbo].[WorkOrders]
        SET LastModifiedDate = GETDATE(), LastModifiedBy = @ModifiedBy
        WHERE WorkOrderId = @WorkOrderId;

        COMMIT TRANSACTION;
        SELECT 1 AS Success, 'Line item deleted successfully' AS Message, @AreaId AS AreaId;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT 0 AS Success, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

-- ============================================================
-- 6. Update Area Name
-- ============================================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_WorkOrder_UpdateAreaName]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[usp_WorkOrder_UpdateAreaName]
GO

CREATE PROCEDURE [dbo].[usp_WorkOrder_UpdateAreaName]
    @WorkOrderId INT,
    @AreaId INT,
    @CustomAreaName NVARCHAR(200),
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @OldName NVARCHAR(200);

        -- Get old name
        SELECT @OldName = ISNULL(CustomAreaName, AreaName)
        FROM [dbo].[WorkOrderAreas]
        WHERE AreaId = @AreaId AND WorkOrderId = @WorkOrderId;

        -- Update custom name
        UPDATE [dbo].[WorkOrderAreas]
        SET CustomAreaName = @CustomAreaName
        WHERE AreaId = @AreaId AND WorkOrderId = @WorkOrderId;

        -- Log the change
        INSERT INTO [dbo].[WorkOrderChangeLog]
            (WorkOrderId, AreaId, ChangeType, FieldName, OldValue, NewValue, ChangedBy)
        VALUES
            (@WorkOrderId, @AreaId, 'AreaRename', 'AreaName', @OldName, @CustomAreaName, @ModifiedBy);

        -- Update work order modified timestamp
        UPDATE [dbo].[WorkOrders]
        SET LastModifiedDate = GETDATE(), LastModifiedBy = @ModifiedBy
        WHERE WorkOrderId = @WorkOrderId;

        COMMIT TRANSACTION;
        SELECT 1 AS Success, 'Area name updated successfully' AS Message;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT 0 AS Success, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

-- ============================================================
-- 7. Get Area and Grand Totals
-- ============================================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_WorkOrder_GetTotals]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[usp_WorkOrder_GetTotals]
GO

CREATE PROCEDURE [dbo].[usp_WorkOrder_GetTotals]
    @WorkOrderId INT,
    @AreaId INT = NULL -- If NULL, return grand totals only
AS
BEGIN
    SET NOCOUNT ON;

    -- Area totals (if AreaId specified)
    IF @AreaId IS NOT NULL
    BEGIN
        SELECT
            @AreaId AS AreaId,
            SUM(li.PrepHrs) AS AreaPrepHours,
            SUM(li.WorkingHrs) AS AreaWorkingHours,
            SUM(li.PrepHrs + li.WorkingHrs) AS AreaTotalHours
        FROM [dbo].[WorkOrderLineItems] li
        WHERE li.AreaId = @AreaId AND li.IsDeleted = 0;
    END

    -- Grand totals
    SELECT
        SUM(li.PrepHrs) AS GrandPrepHours,
        SUM(li.WorkingHrs) AS GrandWorkingHours,
        SUM(li.PrepHrs + li.WorkingHrs) AS GrandTotalHours
    FROM [dbo].[WorkOrderLineItems] li
    INNER JOIN [dbo].[WorkOrderAreas] wa ON li.AreaId = wa.AreaId
    WHERE wa.WorkOrderId = @WorkOrderId AND li.IsDeleted = 0;
END
GO

-- ============================================================
-- 8. Save All Work Order Changes (Batch Save)
-- ============================================================
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_WorkOrder_SaveAll]') AND type in (N'P'))
    DROP PROCEDURE [dbo].[usp_WorkOrder_SaveAll]
GO

CREATE PROCEDURE [dbo].[usp_WorkOrder_SaveAll]
    @WorkOrderId INT,
    @ChangesJson NVARCHAR(MAX), -- JSON containing all changes
    @ModifiedBy NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Parse JSON and apply changes
        -- This uses SQL Server 2016+ JSON functions
        -- For older versions, consider using a table-valued parameter instead

        -- Update area sort orders and custom names
        UPDATE wa
        SET
            wa.SortOrder = ISNULL(JSON_VALUE(a.value, '$.sortOrder'), wa.SortOrder),
            wa.CustomAreaName = JSON_VALUE(a.value, '$.customAreaName')
        FROM [dbo].[WorkOrderAreas] wa
        CROSS APPLY OPENJSON(@ChangesJson, '$.areas') a
        WHERE wa.AreaId = JSON_VALUE(a.value, '$.areaId')
          AND wa.WorkOrderId = @WorkOrderId;

        -- Update line items
        UPDATE li
        SET
            li.PrepHrs = ISNULL(CAST(JSON_VALUE(l.value, '$.prepHrs') AS DECIMAL(10,2)), li.PrepHrs),
            li.WorkingHrs = ISNULL(CAST(JSON_VALUE(l.value, '$.workingHrs') AS DECIMAL(10,2)), li.WorkingHrs),
            li.Unit = ISNULL(JSON_VALUE(l.value, '$.unit'), li.Unit),
            li.Coats = ISNULL(CAST(JSON_VALUE(l.value, '$.coats') AS INT), li.Coats),
            li.SortOrder = ISNULL(CAST(JSON_VALUE(l.value, '$.sortOrder') AS INT), li.SortOrder),
            li.IsDeleted = ISNULL(CAST(JSON_VALUE(l.value, '$.isDeleted') AS BIT), li.IsDeleted),
            li.DeletedDate = CASE WHEN CAST(JSON_VALUE(l.value, '$.isDeleted') AS BIT) = 1 AND li.IsDeleted = 0 THEN GETDATE() ELSE li.DeletedDate END,
            li.IsModified = 1
        FROM [dbo].[WorkOrderLineItems] li
        CROSS APPLY OPENJSON(@ChangesJson, '$.areas') a
        CROSS APPLY OPENJSON(a.value, '$.lineItems') l
        WHERE li.LineItemId = JSON_VALUE(l.value, '$.lineItemId')
          AND li.AreaId = JSON_VALUE(a.value, '$.areaId');

        -- Log batch save
        INSERT INTO [dbo].[WorkOrderChangeLog]
            (WorkOrderId, ChangeType, NewValue, ChangedBy)
        VALUES
            (@WorkOrderId, 'BatchSave', @ChangesJson, @ModifiedBy);

        -- Update work order modified timestamp
        UPDATE [dbo].[WorkOrders]
        SET LastModifiedDate = GETDATE(), LastModifiedBy = @ModifiedBy
        WHERE WorkOrderId = @WorkOrderId;

        COMMIT TRANSACTION;
        SELECT 1 AS Success, 'All changes saved successfully' AS Message;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SELECT 0 AS Success, ERROR_MESSAGE() AS Message;
    END CATCH
END
GO

PRINT '============================================================';
PRINT 'Stored procedures created successfully!';
PRINT '============================================================';
