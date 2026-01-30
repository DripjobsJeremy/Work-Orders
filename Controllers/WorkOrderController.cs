using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Web.Mvc;
using DripJobs.Models.WorkOrder;
using Newtonsoft.Json;

namespace DripJobs.Controllers
{
    /// <summary>
    /// Controller for Work Order customization features
    /// Phase 1: Edit, reorder, and delete line items and areas
    /// </summary>
    public class WorkOrderController : Controller
    {
        private readonly string _connectionString;

        public WorkOrderController()
        {
            _connectionString = ConfigurationManager.ConnectionStrings["DripJobsConnection"].ConnectionString;
        }

        #region View Actions

        /// <summary>
        /// GET: WorkOrder/Edit/{id}
        /// Display the Work Order edit view
        /// </summary>
        [HttpGet]
        public ActionResult Edit(int id)
        {
            try
            {
                var viewModel = GetWorkOrderForEdit(id);

                if (viewModel == null)
                {
                    TempData["Error"] = "Work Order not found.";
                    return RedirectToAction("Index", "WorkOrder");
                }

                return View(viewModel);
            }
            catch (Exception ex)
            {
                // Log exception
                System.Diagnostics.Debug.WriteLine($"Error loading Work Order: {ex.Message}");
                TempData["Error"] = "An error occurred while loading the Work Order.";
                return RedirectToAction("Index", "WorkOrder");
            }
        }

        #endregion

        #region API Actions

        /// <summary>
        /// POST: WorkOrder/SaveChanges
        /// Save all changes to the Work Order
        /// </summary>
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult SaveChanges(SaveWorkOrderRequest request)
        {
            var response = new WorkOrderApiResponse();

            try
            {
                if (request == null || request.WorkOrderId <= 0)
                {
                    response.Success = false;
                    response.Message = "Invalid request.";
                    return Json(response);
                }

                var currentUser = GetCurrentUserName();
                var changesJson = JsonConvert.SerializeObject(request);

                using (var connection = new SqlConnection(_connectionString))
                {
                    connection.Open();
                    using (var command = new SqlCommand("usp_WorkOrder_SaveAll", connection))
                    {
                        command.CommandType = CommandType.StoredProcedure;
                        command.Parameters.AddWithValue("@WorkOrderId", request.WorkOrderId);
                        command.Parameters.AddWithValue("@ChangesJson", changesJson);
                        command.Parameters.AddWithValue("@ModifiedBy", currentUser);

                        using (var reader = command.ExecuteReader())
                        {
                            if (reader.Read())
                            {
                                response.Success = Convert.ToBoolean(reader["Success"]);
                                response.Message = reader["Message"].ToString();
                            }
                        }
                    }

                    // Get updated totals
                    if (response.Success)
                    {
                        response.Totals = GetWorkOrderTotals(connection, request.WorkOrderId, null);
                    }
                }
            }
            catch (Exception ex)
            {
                response.Success = false;
                response.Message = "An error occurred while saving changes.";
                response.Errors.Add(ex.Message);
                System.Diagnostics.Debug.WriteLine($"SaveChanges error: {ex.Message}");
            }

            return Json(response);
        }

        /// <summary>
        /// POST: WorkOrder/ReorderLineItems
        /// Reorder line items within an area
        /// </summary>
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult ReorderLineItems(ReorderLineItemsRequest request)
        {
            var response = new WorkOrderApiResponse();

            try
            {
                if (request == null || request.LineItemIds == null || !request.LineItemIds.Any())
                {
                    response.Success = false;
                    response.Message = "Invalid request.";
                    return Json(response);
                }

                var currentUser = GetCurrentUserName();
                var lineItemIdsString = string.Join(",", request.LineItemIds);

                using (var connection = new SqlConnection(_connectionString))
                {
                    connection.Open();
                    using (var command = new SqlCommand("usp_WorkOrder_ReorderLineItems", connection))
                    {
                        command.CommandType = CommandType.StoredProcedure;
                        command.Parameters.AddWithValue("@WorkOrderId", request.WorkOrderId);
                        command.Parameters.AddWithValue("@AreaId", request.AreaId);
                        command.Parameters.AddWithValue("@LineItemIds", lineItemIdsString);
                        command.Parameters.AddWithValue("@ModifiedBy", currentUser);

                        using (var reader = command.ExecuteReader())
                        {
                            if (reader.Read())
                            {
                                response.Success = Convert.ToBoolean(reader["Success"]);
                                response.Message = reader["Message"].ToString();
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                response.Success = false;
                response.Message = "An error occurred while reordering line items.";
                response.Errors.Add(ex.Message);
            }

            return Json(response);
        }

        /// <summary>
        /// POST: WorkOrder/ReorderAreas
        /// Reorder areas/sections
        /// </summary>
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult ReorderAreas(ReorderAreasRequest request)
        {
            var response = new WorkOrderApiResponse();

            try
            {
                if (request == null || request.AreaIds == null || !request.AreaIds.Any())
                {
                    response.Success = false;
                    response.Message = "Invalid request.";
                    return Json(response);
                }

                var currentUser = GetCurrentUserName();
                var areaIdsString = string.Join(",", request.AreaIds);

                using (var connection = new SqlConnection(_connectionString))
                {
                    connection.Open();
                    using (var command = new SqlCommand("usp_WorkOrder_ReorderAreas", connection))
                    {
                        command.CommandType = CommandType.StoredProcedure;
                        command.Parameters.AddWithValue("@WorkOrderId", request.WorkOrderId);
                        command.Parameters.AddWithValue("@AreaIds", areaIdsString);
                        command.Parameters.AddWithValue("@ModifiedBy", currentUser);

                        using (var reader = command.ExecuteReader())
                        {
                            if (reader.Read())
                            {
                                response.Success = Convert.ToBoolean(reader["Success"]);
                                response.Message = reader["Message"].ToString();
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                response.Success = false;
                response.Message = "An error occurred while reordering areas.";
                response.Errors.Add(ex.Message);
            }

            return Json(response);
        }

        /// <summary>
        /// POST: WorkOrder/UpdateLineItem
        /// Update a single line item field
        /// </summary>
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult UpdateLineItem(UpdateLineItemRequest request)
        {
            var response = new WorkOrderApiResponse();

            try
            {
                if (request == null || string.IsNullOrEmpty(request.Field))
                {
                    response.Success = false;
                    response.Message = "Invalid request.";
                    return Json(response);
                }

                // Validate field name
                var validFields = new[] { "PrepHrs", "WorkingHrs", "Unit", "Coats" };
                if (!validFields.Contains(request.Field))
                {
                    response.Success = false;
                    response.Message = "Invalid field name.";
                    return Json(response);
                }

                // Validate numeric values
                if (request.Field == "PrepHrs" || request.Field == "WorkingHrs")
                {
                    if (!decimal.TryParse(request.Value, out decimal hours) || hours < 0 || hours > 24)
                    {
                        response.Success = false;
                        response.Message = "Hours must be between 0 and 24.";
                        return Json(response);
                    }
                }
                else if (request.Field == "Coats")
                {
                    if (!int.TryParse(request.Value, out int coats) || coats < 0 || coats > 100)
                    {
                        response.Success = false;
                        response.Message = "Coats must be between 0 and 100.";
                        return Json(response);
                    }
                }

                var currentUser = GetCurrentUserName();
                int areaId = 0;

                using (var connection = new SqlConnection(_connectionString))
                {
                    connection.Open();
                    using (var command = new SqlCommand("usp_WorkOrder_UpdateLineItem", connection))
                    {
                        command.CommandType = CommandType.StoredProcedure;
                        command.Parameters.AddWithValue("@WorkOrderId", request.WorkOrderId);
                        command.Parameters.AddWithValue("@LineItemId", request.LineItemId);
                        command.Parameters.AddWithValue("@FieldName", request.Field);
                        command.Parameters.AddWithValue("@NewValue", request.Value ?? "");
                        command.Parameters.AddWithValue("@ModifiedBy", currentUser);

                        using (var reader = command.ExecuteReader())
                        {
                            if (reader.Read())
                            {
                                response.Success = Convert.ToBoolean(reader["Success"]);
                                response.Message = reader["Message"].ToString();

                                if (response.Success && reader.FieldCount > 2)
                                {
                                    areaId = Convert.ToInt32(reader["AreaId"]);
                                    response.Data = new
                                    {
                                        prepHrs = Convert.ToDecimal(reader["PrepHrs"]),
                                        workingHrs = Convert.ToDecimal(reader["WorkingHrs"]),
                                        totalHrs = Convert.ToDecimal(reader["TotalHrs"]),
                                        unit = reader["Unit"].ToString(),
                                        coats = Convert.ToInt32(reader["Coats"])
                                    };
                                }
                            }
                        }
                    }

                    // Get updated totals
                    if (response.Success && areaId > 0)
                    {
                        response.Totals = GetWorkOrderTotals(connection, request.WorkOrderId, areaId);
                    }
                }
            }
            catch (Exception ex)
            {
                response.Success = false;
                response.Message = "An error occurred while updating the line item.";
                response.Errors.Add(ex.Message);
            }

            return Json(response);
        }

        /// <summary>
        /// POST: WorkOrder/DeleteLineItem
        /// Soft delete a line item
        /// </summary>
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult DeleteLineItem(DeleteLineItemRequest request)
        {
            var response = new WorkOrderApiResponse();

            try
            {
                if (request == null || request.LineItemId <= 0)
                {
                    response.Success = false;
                    response.Message = "Invalid request.";
                    return Json(response);
                }

                var currentUser = GetCurrentUserName();
                int areaId = 0;

                using (var connection = new SqlConnection(_connectionString))
                {
                    connection.Open();
                    using (var command = new SqlCommand("usp_WorkOrder_DeleteLineItem", connection))
                    {
                        command.CommandType = CommandType.StoredProcedure;
                        command.Parameters.AddWithValue("@WorkOrderId", request.WorkOrderId);
                        command.Parameters.AddWithValue("@LineItemId", request.LineItemId);
                        command.Parameters.AddWithValue("@ModifiedBy", currentUser);

                        using (var reader = command.ExecuteReader())
                        {
                            if (reader.Read())
                            {
                                response.Success = Convert.ToBoolean(reader["Success"]);
                                response.Message = reader["Message"].ToString();
                                if (reader.FieldCount > 2)
                                {
                                    areaId = Convert.ToInt32(reader["AreaId"]);
                                }
                            }
                        }
                    }

                    // Get updated totals
                    if (response.Success && areaId > 0)
                    {
                        response.Totals = GetWorkOrderTotals(connection, request.WorkOrderId, areaId);
                    }
                }
            }
            catch (Exception ex)
            {
                response.Success = false;
                response.Message = "An error occurred while deleting the line item.";
                response.Errors.Add(ex.Message);
            }

            return Json(response);
        }

        /// <summary>
        /// POST: WorkOrder/UpdateAreaName
        /// Update an area's custom name
        /// </summary>
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult UpdateAreaName(UpdateAreaNameRequest request)
        {
            var response = new WorkOrderApiResponse();

            try
            {
                if (request == null || request.AreaId <= 0)
                {
                    response.Success = false;
                    response.Message = "Invalid request.";
                    return Json(response);
                }

                if (string.IsNullOrWhiteSpace(request.CustomAreaName))
                {
                    response.Success = false;
                    response.Message = "Area name cannot be empty.";
                    return Json(response);
                }

                if (request.CustomAreaName.Length > 200)
                {
                    response.Success = false;
                    response.Message = "Area name cannot exceed 200 characters.";
                    return Json(response);
                }

                var currentUser = GetCurrentUserName();

                using (var connection = new SqlConnection(_connectionString))
                {
                    connection.Open();
                    using (var command = new SqlCommand("usp_WorkOrder_UpdateAreaName", connection))
                    {
                        command.CommandType = CommandType.StoredProcedure;
                        command.Parameters.AddWithValue("@WorkOrderId", request.WorkOrderId);
                        command.Parameters.AddWithValue("@AreaId", request.AreaId);
                        command.Parameters.AddWithValue("@CustomAreaName", request.CustomAreaName.Trim());
                        command.Parameters.AddWithValue("@ModifiedBy", currentUser);

                        using (var reader = command.ExecuteReader())
                        {
                            if (reader.Read())
                            {
                                response.Success = Convert.ToBoolean(reader["Success"]);
                                response.Message = reader["Message"].ToString();
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                response.Success = false;
                response.Message = "An error occurred while updating the area name.";
                response.Errors.Add(ex.Message);
            }

            return Json(response);
        }

        /// <summary>
        /// GET: WorkOrder/GetTotals
        /// Get updated totals for an area and/or entire work order
        /// </summary>
        [HttpGet]
        public ActionResult GetTotals(int workOrderId, int? areaId = null)
        {
            var response = new WorkOrderApiResponse();

            try
            {
                using (var connection = new SqlConnection(_connectionString))
                {
                    connection.Open();
                    response.Totals = GetWorkOrderTotals(connection, workOrderId, areaId);
                    response.Success = true;
                }
            }
            catch (Exception ex)
            {
                response.Success = false;
                response.Message = "An error occurred while retrieving totals.";
                response.Errors.Add(ex.Message);
            }

            return Json(response, JsonRequestBehavior.AllowGet);
        }

        #endregion

        #region Private Methods

        private WorkOrderEditViewModel GetWorkOrderForEdit(int workOrderId)
        {
            WorkOrderEditViewModel viewModel = null;

            using (var connection = new SqlConnection(_connectionString))
            {
                connection.Open();
                using (var command = new SqlCommand("usp_WorkOrder_GetForEdit", connection))
                {
                    command.CommandType = CommandType.StoredProcedure;
                    command.Parameters.AddWithValue("@WorkOrderId", workOrderId);

                    using (var reader = command.ExecuteReader())
                    {
                        // Read Work Order header
                        if (reader.Read())
                        {
                            viewModel = new WorkOrderEditViewModel
                            {
                                WorkOrderId = Convert.ToInt32(reader["WorkOrderId"]),
                                ProposalNumber = reader["ProposalNumber"]?.ToString(),
                                ProposalState = reader["ProposalState"]?.ToString(),
                                CustomerName = reader["CustomerName"]?.ToString(),
                                JobName = reader["JobName"]?.ToString(),
                                JobAddress = reader["JobAddress"]?.ToString(),
                                LastModified = reader["LastModifiedDate"] as DateTime?,
                                LastModifiedBy = reader["LastModifiedBy"]?.ToString(),
                                OriginalProposalId = reader["OriginalProposalId"] as int?
                            };
                        }

                        if (viewModel == null) return null;

                        // Read Areas
                        var areas = new Dictionary<int, WorkOrderAreaViewModel>();
                        if (reader.NextResult())
                        {
                            while (reader.Read())
                            {
                                var area = new WorkOrderAreaViewModel
                                {
                                    AreaId = Convert.ToInt32(reader["AreaId"]),
                                    AreaName = reader["AreaName"]?.ToString(),
                                    CustomAreaName = reader["CustomAreaName"]?.ToString(),
                                    SortOrder = Convert.ToInt32(reader["SortOrder"])
                                };
                                areas[area.AreaId] = area;
                            }
                        }

                        // Read Line Items
                        if (reader.NextResult())
                        {
                            while (reader.Read())
                            {
                                var areaId = Convert.ToInt32(reader["AreaId"]);
                                if (areas.ContainsKey(areaId))
                                {
                                    var lineItem = new WorkOrderLineItemViewModel
                                    {
                                        LineItemId = Convert.ToInt32(reader["LineItemId"]),
                                        AreaId = areaId,
                                        ItemName = reader["ItemName"]?.ToString(),
                                        ItemType = reader["ItemType"]?.ToString(),
                                        ProductName = reader["ProductName"]?.ToString(),
                                        Sheen = reader["Sheen"]?.ToString(),
                                        Color = reader["Color"]?.ToString(),
                                        PrepHrs = Convert.ToDecimal(reader["PrepHrs"]),
                                        WorkingHrs = Convert.ToDecimal(reader["WorkingHrs"]),
                                        Unit = reader["Unit"]?.ToString(),
                                        Coats = Convert.ToInt32(reader["Coats"]),
                                        SortOrder = Convert.ToInt32(reader["SortOrder"]),
                                        IsDeleted = Convert.ToBoolean(reader["IsDeleted"]),
                                        DeletedDate = reader["DeletedDate"] as DateTime?,
                                        IsModified = Convert.ToBoolean(reader["IsModified"]),
                                        OriginalPrepHrs = reader["OriginalPrepHrs"] as decimal?,
                                        OriginalWorkingHrs = reader["OriginalWorkingHrs"] as decimal?,
                                        OriginalUnit = reader["OriginalUnit"]?.ToString(),
                                        OriginalCoats = reader["OriginalCoats"] as int?
                                    };
                                    areas[areaId].LineItems.Add(lineItem);
                                }
                            }
                        }

                        viewModel.Areas = areas.Values
                            .OrderBy(a => a.SortOrder)
                            .ThenBy(a => a.AreaId)
                            .ToList();
                    }
                }
            }

            return viewModel;
        }

        private TotalsViewModel GetWorkOrderTotals(SqlConnection connection, int workOrderId, int? areaId)
        {
            var totals = new TotalsViewModel();

            using (var command = new SqlCommand("usp_WorkOrder_GetTotals", connection))
            {
                command.CommandType = CommandType.StoredProcedure;
                command.Parameters.AddWithValue("@WorkOrderId", workOrderId);
                command.Parameters.AddWithValue("@AreaId", (object)areaId ?? DBNull.Value);

                using (var reader = command.ExecuteReader())
                {
                    // Read area totals if areaId was specified
                    if (areaId.HasValue && reader.Read())
                    {
                        totals.AreaPrepHours = reader["AreaPrepHours"] != DBNull.Value
                            ? Convert.ToDecimal(reader["AreaPrepHours"]) : 0;
                        totals.AreaWorkingHours = reader["AreaWorkingHours"] != DBNull.Value
                            ? Convert.ToDecimal(reader["AreaWorkingHours"]) : 0;
                        totals.AreaTotalHours = reader["AreaTotalHours"] != DBNull.Value
                            ? Convert.ToDecimal(reader["AreaTotalHours"]) : 0;
                    }

                    // Read grand totals
                    if ((areaId.HasValue && reader.NextResult()) || (!areaId.HasValue))
                    {
                        if (reader.Read())
                        {
                            totals.GrandPrepHours = reader["GrandPrepHours"] != DBNull.Value
                                ? Convert.ToDecimal(reader["GrandPrepHours"]) : 0;
                            totals.GrandWorkingHours = reader["GrandWorkingHours"] != DBNull.Value
                                ? Convert.ToDecimal(reader["GrandWorkingHours"]) : 0;
                            totals.GrandTotalHours = reader["GrandTotalHours"] != DBNull.Value
                                ? Convert.ToDecimal(reader["GrandTotalHours"]) : 0;
                        }
                    }
                }
            }

            return totals;
        }

        private string GetCurrentUserName()
        {
            // Get current authenticated user
            // This should match your existing authentication implementation
            if (User != null && User.Identity != null && User.Identity.IsAuthenticated)
            {
                return User.Identity.Name;
            }
            return "System";
        }

        #endregion
    }
}
