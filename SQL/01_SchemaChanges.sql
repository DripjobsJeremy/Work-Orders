-- ============================================================
-- DripJobs Work Order Customization - Phase 1
-- Database Schema Changes
-- ============================================================
-- Run this script to add the necessary columns and tables
-- for Work Order customization functionality
-- ============================================================

-- ============================================================
-- 1. Add SortOrder column to WorkOrderAreas table
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[WorkOrderAreas]') AND name = 'SortOrder')
BEGIN
    ALTER TABLE [dbo].[WorkOrderAreas]
    ADD [SortOrder] INT NOT NULL DEFAULT 0;
    PRINT 'Added SortOrder column to WorkOrderAreas table';
END
GO

-- ============================================================
-- 2. Add CustomAreaName column to WorkOrderAreas table
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[WorkOrderAreas]') AND name = 'CustomAreaName')
BEGIN
    ALTER TABLE [dbo].[WorkOrderAreas]
    ADD [CustomAreaName] NVARCHAR(200) NULL;
    PRINT 'Added CustomAreaName column to WorkOrderAreas table';
END
GO

-- ============================================================
-- 3. Add SortOrder column to WorkOrderLineItems table
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[WorkOrderLineItems]') AND name = 'SortOrder')
BEGIN
    ALTER TABLE [dbo].[WorkOrderLineItems]
    ADD [SortOrder] INT NOT NULL DEFAULT 0;
    PRINT 'Added SortOrder column to WorkOrderLineItems table';
END
GO

-- ============================================================
-- 4. Add IsDeleted column to WorkOrderLineItems table (soft delete)
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[WorkOrderLineItems]') AND name = 'IsDeleted')
BEGIN
    ALTER TABLE [dbo].[WorkOrderLineItems]
    ADD [IsDeleted] BIT NOT NULL DEFAULT 0;
    PRINT 'Added IsDeleted column to WorkOrderLineItems table';
END
GO

-- ============================================================
-- 5. Add DeletedDate column to WorkOrderLineItems table
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[WorkOrderLineItems]') AND name = 'DeletedDate')
BEGIN
    ALTER TABLE [dbo].[WorkOrderLineItems]
    ADD [DeletedDate] DATETIME NULL;
    PRINT 'Added DeletedDate column to WorkOrderLineItems table';
END
GO

-- ============================================================
-- 6. Add IsModified column to WorkOrderLineItems table
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[WorkOrderLineItems]') AND name = 'IsModified')
BEGIN
    ALTER TABLE [dbo].[WorkOrderLineItems]
    ADD [IsModified] BIT NOT NULL DEFAULT 0;
    PRINT 'Added IsModified column to WorkOrderLineItems table';
END
GO

-- ============================================================
-- 7. Add Original Value columns to WorkOrderLineItems table
--    These store the original proposal values for comparison/revert
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[WorkOrderLineItems]') AND name = 'OriginalPrepHrs')
BEGIN
    ALTER TABLE [dbo].[WorkOrderLineItems]
    ADD [OriginalPrepHrs] DECIMAL(10,2) NULL;
    PRINT 'Added OriginalPrepHrs column to WorkOrderLineItems table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[WorkOrderLineItems]') AND name = 'OriginalWorkingHrs')
BEGIN
    ALTER TABLE [dbo].[WorkOrderLineItems]
    ADD [OriginalWorkingHrs] DECIMAL(10,2) NULL;
    PRINT 'Added OriginalWorkingHrs column to WorkOrderLineItems table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[WorkOrderLineItems]') AND name = 'OriginalUnit')
BEGIN
    ALTER TABLE [dbo].[WorkOrderLineItems]
    ADD [OriginalUnit] NVARCHAR(50) NULL;
    PRINT 'Added OriginalUnit column to WorkOrderLineItems table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[WorkOrderLineItems]') AND name = 'OriginalCoats')
BEGIN
    ALTER TABLE [dbo].[WorkOrderLineItems]
    ADD [OriginalCoats] INT NULL;
    PRINT 'Added OriginalCoats column to WorkOrderLineItems table';
END
GO

-- ============================================================
-- 8. Add LastModified columns to WorkOrders table
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[WorkOrders]') AND name = 'LastModifiedDate')
BEGIN
    ALTER TABLE [dbo].[WorkOrders]
    ADD [LastModifiedDate] DATETIME NULL;
    PRINT 'Added LastModifiedDate column to WorkOrders table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[WorkOrders]') AND name = 'LastModifiedBy')
BEGIN
    ALTER TABLE [dbo].[WorkOrders]
    ADD [LastModifiedBy] NVARCHAR(100) NULL;
    PRINT 'Added LastModifiedBy column to WorkOrders table';
END
GO

-- ============================================================
-- 9. Create WorkOrderChangeLog table for audit trail
-- ============================================================
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[WorkOrderChangeLog]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[WorkOrderChangeLog] (
        [ChangeLogId] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [WorkOrderId] INT NOT NULL,
        [AreaId] INT NULL,
        [LineItemId] INT NULL,
        [ChangeType] NVARCHAR(50) NOT NULL, -- 'LineItemUpdate', 'LineItemDelete', 'LineItemReorder', 'AreaReorder', 'AreaRename'
        [FieldName] NVARCHAR(50) NULL,
        [OldValue] NVARCHAR(MAX) NULL,
        [NewValue] NVARCHAR(MAX) NULL,
        [ChangedBy] NVARCHAR(100) NOT NULL,
        [ChangedDate] DATETIME NOT NULL DEFAULT GETDATE(),

        INDEX [IX_WorkOrderChangeLog_WorkOrderId] NONCLUSTERED ([WorkOrderId]),
        INDEX [IX_WorkOrderChangeLog_ChangedDate] NONCLUSTERED ([ChangedDate])
    );
    PRINT 'Created WorkOrderChangeLog table';
END
GO

-- ============================================================
-- 10. Initialize SortOrder values for existing data
-- ============================================================
-- Set default sort order for areas based on existing ID order
UPDATE wa
SET wa.SortOrder = ranked.RowNum
FROM [dbo].[WorkOrderAreas] wa
INNER JOIN (
    SELECT AreaId, ROW_NUMBER() OVER (PARTITION BY WorkOrderId ORDER BY AreaId) as RowNum
    FROM [dbo].[WorkOrderAreas]
    WHERE SortOrder = 0
) ranked ON wa.AreaId = ranked.AreaId
WHERE wa.SortOrder = 0;

-- Set default sort order for line items based on existing ID order
UPDATE li
SET li.SortOrder = ranked.RowNum
FROM [dbo].[WorkOrderLineItems] li
INNER JOIN (
    SELECT LineItemId, ROW_NUMBER() OVER (PARTITION BY AreaId ORDER BY LineItemId) as RowNum
    FROM [dbo].[WorkOrderLineItems]
    WHERE SortOrder = 0
) ranked ON li.LineItemId = ranked.LineItemId
WHERE li.SortOrder = 0;

PRINT 'Initialized SortOrder values for existing data';
GO

-- ============================================================
-- 11. Store original values for existing line items
-- ============================================================
UPDATE [dbo].[WorkOrderLineItems]
SET
    OriginalPrepHrs = PrepHrs,
    OriginalWorkingHrs = WorkingHrs,
    OriginalUnit = Unit,
    OriginalCoats = Coats
WHERE OriginalPrepHrs IS NULL;

PRINT 'Stored original values for existing line items';
GO

PRINT '============================================================';
PRINT 'Schema changes completed successfully!';
PRINT '============================================================';
