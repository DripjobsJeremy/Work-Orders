# DripJobs Work Order Customization - Phase 1

## Overview

This implementation provides production-ready code for Work Order customization functionality, allowing users to:
- Edit line item fields inline (Prep Hrs, Working Hrs, Unit, Coats)
- Remove line items from Work Orders (with confirmation)
- Reorder line items within an area/section (drag and drop)
- Reorder entire sections/areas (drag and drop)
- Edit area/section names
- See totals update automatically

**IMPORTANT**: All changes are isolated to the Work Order and do NOT affect the original Proposal or Job Costing records.

## Files Structure

```
WorkOrderCustomization/
├── Models/
│   └── WorkOrderViewModels.cs      # ViewModels and API request/response models
├── Controllers/
│   └── WorkOrderController.cs      # MVC Controller with all actions
├── Views/
│   └── WorkOrder/
│       └── Edit.cshtml             # Razor view with Bootstrap 4
├── Content/
│   └── css/
│       └── workorder-edit.css      # Custom styles
├── Scripts/
│   └── workorder-edit.js           # jQuery/JavaScript with drag-and-drop
├── SQL/
│   ├── 01_SchemaChanges.sql        # Database schema modifications
│   └── 02_StoredProcedures.sql     # Stored procedures
└── README.md                       # This file
```

## Integration Steps

### Step 1: Database Changes

1. **Backup your database** before running any scripts
2. Run the SQL scripts in order:
   ```sql
   -- Run first
   01_SchemaChanges.sql

   -- Run second
   02_StoredProcedures.sql
   ```
3. Verify the new columns and stored procedures were created successfully

### Step 2: Add Models

1. Copy `WorkOrderViewModels.cs` to your `Models` folder
2. Adjust the namespace to match your project:
   ```csharp
   namespace YourProjectName.Models.WorkOrder
   ```

### Step 3: Add Controller

1. Copy `WorkOrderController.cs` to your `Controllers` folder
2. Update the namespace
3. Update the connection string name if different:
   ```csharp
   _connectionString = ConfigurationManager.ConnectionStrings["YourConnectionStringName"].ConnectionString;
   ```
4. Update `GetCurrentUserName()` method to match your authentication:
   ```csharp
   private string GetCurrentUserName()
   {
       // Match your existing auth implementation
       return User.Identity.Name;
   }
   ```

### Step 4: Add View

1. Copy `Edit.cshtml` to `Views/WorkOrder/`
2. Verify the layout path matches your project:
   ```razor
   Layout = "~/Views/Shared/_Layout.cshtml";
   ```
3. Update any asset paths as needed

### Step 5: Add Static Assets

1. Copy `workorder-edit.css` to `Content/css/`
2. Copy `workorder-edit.js` to `Scripts/`
3. Add references to `BundleConfig.cs` if using bundles:
   ```csharp
   bundles.Add(new StyleBundle("~/bundles/workorder-css")
       .Include("~/Content/css/workorder-edit.css"));

   bundles.Add(new ScriptBundle("~/bundles/workorder-js")
       .Include("~/Scripts/workorder-edit.js"));
   ```

### Step 6: Add Required Dependencies

Ensure these libraries are included (add to your layout or bundle):

```html
<!-- jQuery (should already be present) -->
<script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>

<!-- jQuery UI (required for drag-and-drop) -->
<script src="https://code.jquery.com/ui/1.12.1/jquery-ui.min.js"></script>

<!-- Touch Punch (required for mobile drag-and-drop) -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/jqueryui-touch-punch/0.2.3/jquery.ui.touch-punch.min.js"></script>
```

Or install via NuGet:
```
Install-Package jQuery.UI.Combined
```

### Step 7: Add Route (if needed)

If you're using attribute routing or custom routes, add:
```csharp
routes.MapRoute(
    name: "WorkOrderEdit",
    url: "WorkOrder/Edit/{id}",
    defaults: new { controller = "WorkOrder", action = "Edit" }
);
```

### Step 8: Update Web.config

Ensure JSON serialization settings support your API calls:
```xml
<system.web.extensions>
  <scripting>
    <webServices>
      <jsonSerialization maxJsonLength="2147483647"/>
    </webServices>
  </scripting>
</system.web.extensions>
```

## Testing

After integration, test these scenarios:

### Basic Functionality
1. Navigate to `/WorkOrder/Edit/{id}` with a valid work order ID
2. Click "Edit Work Order" to enter edit mode
3. Verify drag handles appear for areas and line items

### Drag and Drop (CRITICAL)
1. **Line Items**: Click and drag the ⋮⋮ handle next to any line item
   - Item should move smoothly
   - Placeholder should appear showing drop position
   - New order should persist after release
2. **Areas/Sections**: Click and drag the ⋮⋮ handle in the area header
   - Entire section should move
   - New order should persist after release

### Inline Editing
1. Click on Prep Hrs, Working Hrs, Unit, or Coats fields
2. Edit the value
3. Press Enter or click away
4. Verify Total Hrs updates automatically
5. Verify area and grand totals update

### Delete
1. Click the red X button on any line item
2. Confirm in the modal
3. Verify item is removed and totals update

### Save/Cancel
1. Make changes
2. Verify "Unsaved changes" indicator appears
3. Click Cancel - verify prompt appears
4. Click Save - verify changes persist
5. Refresh page - verify changes are still there

## Troubleshooting

### Drag and Drop Not Working

1. **Check jQuery UI is loaded**:
   ```javascript
   console.log($.ui.version); // Should output version number
   ```

2. **Check Sortable is initialized**:
   ```javascript
   console.log($('#wo-areas-container').sortable('instance'));
   ```

3. **Check edit mode is active**:
   ```javascript
   console.log($('.wo-edit-page').hasClass('wo-edit-mode'));
   ```

4. **Mobile devices**: Ensure Touch Punch is loaded for touch support

### API Errors

1. Check browser console for JavaScript errors
2. Check Network tab for failed requests
3. Verify AntiForgeryToken is being sent
4. Check server logs for exceptions

### CSS Issues

1. Verify Bootstrap 4 is loaded
2. Check for CSS conflicts with existing styles
3. Use browser dev tools to inspect elements

## Browser Support

- Chrome 70+
- Firefox 65+
- Safari 12+
- Edge 79+
- Mobile Safari (iOS 12+)
- Chrome for Android

## Security Notes

1. All API endpoints require AntiForgeryToken
2. User authentication should be verified in each action
3. All input is validated server-side
4. Changes are logged in WorkOrderChangeLog table

## Performance Considerations

1. All changes are saved individually via AJAX
2. Totals are recalculated on both client and server
3. For large work orders (100+ items), consider pagination

## Future Enhancements (Phase 2+)

- Undo/Redo functionality
- Copy line items between areas
- Bulk operations
- Activity log UI
- Print optimizations
- Offline support

## Support

For issues or questions, contact the development team or create an issue in the project repository.

---

**Version**: 1.0.0
**Last Updated**: January 2026
**Compatibility**: .NET Framework 4.6+, Bootstrap 4, jQuery 3.x
