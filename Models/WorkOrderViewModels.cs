using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;

namespace DripJobs.Models.WorkOrder
{
    /// <summary>
    /// Main ViewModel for the Work Order Edit page
    /// </summary>
    public class WorkOrderEditViewModel
    {
        public int WorkOrderId { get; set; }

        [Display(Name = "Proposal Number")]
        public string ProposalNumber { get; set; }

        [Display(Name = "Proposal State")]
        public string ProposalState { get; set; }

        [Display(Name = "Customer Name")]
        public string CustomerName { get; set; }

        [Display(Name = "Job Name")]
        public string JobName { get; set; }

        [Display(Name = "Job Address")]
        public string JobAddress { get; set; }

        public DateTime? LastModified { get; set; }
        public string LastModifiedBy { get; set; }

        public List<WorkOrderAreaViewModel> Areas { get; set; } = new List<WorkOrderAreaViewModel>();

        // Calculated totals
        public decimal TotalPrepHours => Areas?.Sum(a => a.TotalPrepHours) ?? 0;
        public decimal TotalWorkingHours => Areas?.Sum(a => a.TotalWorkingHours) ?? 0;
        public decimal GrandTotalHours => Areas?.Sum(a => a.TotalHours) ?? 0;
        public int TotalLineItems => Areas?.Sum(a => a.LineItems?.Count(li => !li.IsDeleted) ?? 0) ?? 0;

        // For tracking unsaved changes
        public bool HasUnsavedChanges { get; set; }

        // Reference to original proposal (read-only display)
        public int? OriginalProposalId { get; set; }
    }

    /// <summary>
    /// ViewModel for Work Order Areas/Sections (e.g., "Guest Bedroom", "Whole House")
    /// </summary>
    public class WorkOrderAreaViewModel
    {
        public int AreaId { get; set; }

        [Required(ErrorMessage = "Area name is required")]
        [StringLength(200, ErrorMessage = "Area name cannot exceed 200 characters")]
        [Display(Name = "Area Name")]
        public string AreaName { get; set; }

        // Original name from proposal (for reference)
        public string OriginalAreaName { get; set; }

        // Custom name if user has edited it
        public string CustomAreaName { get; set; }

        // Display name returns custom name if set, otherwise original
        public string DisplayName => !string.IsNullOrEmpty(CustomAreaName) ? CustomAreaName : AreaName;

        [Range(0, int.MaxValue, ErrorMessage = "Sort order must be a positive number")]
        public int SortOrder { get; set; }

        public bool IsCollapsed { get; set; }

        public List<WorkOrderLineItemViewModel> LineItems { get; set; } = new List<WorkOrderLineItemViewModel>();

        // Calculated area totals (excluding deleted items)
        public decimal TotalPrepHours => LineItems?.Where(li => !li.IsDeleted).Sum(li => li.PrepHrs) ?? 0;
        public decimal TotalWorkingHours => LineItems?.Where(li => !li.IsDeleted).Sum(li => li.WorkingHrs) ?? 0;
        public decimal TotalHours => LineItems?.Where(li => !li.IsDeleted).Sum(li => li.TotalHrs) ?? 0;
        public int ActiveLineItemCount => LineItems?.Count(li => !li.IsDeleted) ?? 0;
    }

    /// <summary>
    /// ViewModel for individual Work Order Line Items
    /// </summary>
    public class WorkOrderLineItemViewModel
    {
        public int LineItemId { get; set; }

        public int AreaId { get; set; }

        [Required(ErrorMessage = "Item name is required")]
        [StringLength(200, ErrorMessage = "Item name cannot exceed 200 characters")]
        [Display(Name = "Item")]
        public string ItemName { get; set; }

        [StringLength(100)]
        [Display(Name = "Type")]
        public string ItemType { get; set; }

        [StringLength(500)]
        [Display(Name = "Product")]
        public string ProductName { get; set; }

        [StringLength(50)]
        public string Sheen { get; set; }

        [StringLength(100)]
        public string Color { get; set; }

        // Formatted product details for display
        public string ProductDetails => FormatProductDetails();

        [Range(0, 24, ErrorMessage = "Prep hours must be between 0 and 24")]
        [Display(Name = "Prep Hrs")]
        public decimal PrepHrs { get; set; }

        [Range(0, 24, ErrorMessage = "Working hours must be between 0 and 24")]
        [Display(Name = "Working Hrs")]
        public decimal WorkingHrs { get; set; }

        // Total Hrs is calculated (Prep + Working)
        [Display(Name = "Total Hrs")]
        public decimal TotalHrs => PrepHrs + WorkingHrs;

        [StringLength(50)]
        [Display(Name = "Unit")]
        public string Unit { get; set; }

        [Range(0, 100, ErrorMessage = "Coats must be between 0 and 100")]
        [Display(Name = "Coats")]
        public int Coats { get; set; }

        [Range(0, int.MaxValue, ErrorMessage = "Sort order must be a positive number")]
        public int SortOrder { get; set; }

        // Soft delete flag
        public bool IsDeleted { get; set; }

        public DateTime? DeletedDate { get; set; }

        // Track if values were edited from original proposal
        public bool IsModified { get; set; }

        // Original values from proposal (for comparison/revert)
        public decimal? OriginalPrepHrs { get; set; }
        public decimal? OriginalWorkingHrs { get; set; }
        public string OriginalUnit { get; set; }
        public int? OriginalCoats { get; set; }

        private string FormatProductDetails()
        {
            var parts = new List<string>();
            if (!string.IsNullOrEmpty(ProductName)) parts.Add(ProductName);
            if (!string.IsNullOrEmpty(Sheen)) parts.Add($"({Sheen})");
            return string.Join(" ", parts);
        }
    }

    #region API Request/Response Models

    /// <summary>
    /// Request model for saving all Work Order changes
    /// </summary>
    public class SaveWorkOrderRequest
    {
        public int WorkOrderId { get; set; }
        public List<AreaSaveModel> Areas { get; set; } = new List<AreaSaveModel>();
    }

    public class AreaSaveModel
    {
        public int AreaId { get; set; }
        public string CustomAreaName { get; set; }
        public int SortOrder { get; set; }
        public List<LineItemSaveModel> LineItems { get; set; } = new List<LineItemSaveModel>();
    }

    public class LineItemSaveModel
    {
        public int LineItemId { get; set; }
        public decimal PrepHrs { get; set; }
        public decimal WorkingHrs { get; set; }
        public string Unit { get; set; }
        public int Coats { get; set; }
        public int SortOrder { get; set; }
        public bool IsDeleted { get; set; }
    }

    /// <summary>
    /// Request model for reordering line items within an area
    /// </summary>
    public class ReorderLineItemsRequest
    {
        public int WorkOrderId { get; set; }
        public int AreaId { get; set; }
        public List<int> LineItemIds { get; set; } = new List<int>(); // IDs in new order
    }

    /// <summary>
    /// Request model for reordering areas/sections
    /// </summary>
    public class ReorderAreasRequest
    {
        public int WorkOrderId { get; set; }
        public List<int> AreaIds { get; set; } = new List<int>(); // IDs in new order
    }

    /// <summary>
    /// Request model for updating a single line item
    /// </summary>
    public class UpdateLineItemRequest
    {
        public int WorkOrderId { get; set; }
        public int LineItemId { get; set; }
        public string Field { get; set; } // "PrepHrs", "WorkingHrs", "Unit", "Coats"
        public string Value { get; set; }
    }

    /// <summary>
    /// Request model for deleting a line item
    /// </summary>
    public class DeleteLineItemRequest
    {
        public int WorkOrderId { get; set; }
        public int LineItemId { get; set; }
    }

    /// <summary>
    /// Request model for updating area name
    /// </summary>
    public class UpdateAreaNameRequest
    {
        public int WorkOrderId { get; set; }
        public int AreaId { get; set; }
        public string CustomAreaName { get; set; }
    }

    /// <summary>
    /// Standard API response model
    /// </summary>
    public class WorkOrderApiResponse
    {
        public bool Success { get; set; }
        public string Message { get; set; }
        public object Data { get; set; }
        public List<string> Errors { get; set; } = new List<string>();

        // Updated totals to send back after changes
        public TotalsViewModel Totals { get; set; }
    }

    public class TotalsViewModel
    {
        public decimal AreaPrepHours { get; set; }
        public decimal AreaWorkingHours { get; set; }
        public decimal AreaTotalHours { get; set; }
        public decimal GrandPrepHours { get; set; }
        public decimal GrandWorkingHours { get; set; }
        public decimal GrandTotalHours { get; set; }
    }

    #endregion
}
