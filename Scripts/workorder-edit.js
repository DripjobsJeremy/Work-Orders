/**
 * DripJobs Work Order Customization - Phase 1
 * JavaScript/jQuery Implementation
 *
 * CRITICAL: This implementation uses jQuery UI Sortable for
 * WORKING drag-and-drop functionality for both line items and areas.
 *
 * Requirements:
 * - jQuery 3.x
 * - jQuery UI 1.12+ (with sortable)
 */

(function ($) {
    'use strict';

    // ============================================================
    // Configuration & State
    // ============================================================
    var WorkOrderEditor = {
        config: {
            workOrderId: 0,
            antiForgeryToken: '',
            apiEndpoints: {
                saveChanges: '/WorkOrder/SaveChanges',
                reorderLineItems: '/WorkOrder/ReorderLineItems',
                reorderAreas: '/WorkOrder/ReorderAreas',
                updateLineItem: '/WorkOrder/UpdateLineItem',
                deleteLineItem: '/WorkOrder/DeleteLineItem',
                updateAreaName: '/WorkOrder/UpdateAreaName',
                getTotals: '/WorkOrder/GetTotals'
            }
        },
        state: {
            isEditMode: false,
            hasUnsavedChanges: false,
            pendingChanges: {},
            deletedItems: []
        },
        elements: {},

        // ============================================================
        // Initialization
        // ============================================================
        init: function (options) {
            var self = this;

            // Merge options
            $.extend(this.config, options);

            // Cache DOM elements
            this.cacheElements();

            // Bind events
            this.bindEvents();

            // Initialize sortable (drag-and-drop) - CRITICAL
            this.initSortable();

            // Setup beforeunload warning
            this.setupBeforeUnload();

            console.log('WorkOrderEditor initialized', this.config);
        },

        cacheElements: function () {
            this.elements = {
                page: $('.wo-edit-page'),
                editModeBtn: $('#wo-edit-mode-btn'),
                saveModeBtn: $('#wo-save-mode-btn'),
                cancelModeBtn: $('#wo-cancel-mode-btn'),
                saveBtn: $('#wo-save-btn'),
                cancelBtn: $('#wo-cancel-btn'),
                areasContainer: $('#wo-areas-container'),
                areaCards: $('.wo-area-card'),
                lineItemsTables: $('.wo-line-items-tbody'),
                unsavedIndicator: $('.wo-unsaved-indicator'),
                toast: $('#wo-toast'),
                deleteModal: $('#wo-delete-modal'),
                grandTotals: {
                    prep: $('#wo-grand-prep-hours'),
                    working: $('#wo-grand-working-hours'),
                    total: $('#wo-grand-total-hours')
                }
            };
        },

        bindEvents: function () {
            var self = this;

            // Edit mode toggle
            this.elements.editModeBtn.on('click', function () {
                self.enterEditMode();
            });

            this.elements.saveModeBtn.on('click', function () {
                self.saveAllChanges();
            });

            this.elements.cancelModeBtn.on('click', function () {
                self.cancelEditMode();
            });

            // Area name editing
            $(document).on('blur', '.wo-area-title-input', function () {
                self.handleAreaNameChange($(this));
            });

            $(document).on('keydown', '.wo-area-title-input', function (e) {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    $(this).blur();
                }
            });

            // Field editing
            $(document).on('blur', '.wo-field-input', function () {
                self.handleFieldChange($(this));
            });

            $(document).on('keydown', '.wo-field-input', function (e) {
                if (e.key === 'Enter') {
                    e.preventDefault();
                    $(this).blur();
                }
                if (e.key === 'Escape') {
                    self.revertFieldValue($(this));
                    $(this).blur();
                }
            });

            // Delete button
            $(document).on('click', '.wo-delete-btn', function (e) {
                e.preventDefault();
                var $row = $(this).closest('.wo-line-item-row');
                self.showDeleteConfirmation($row);
            });

            // Delete modal buttons
            $('#wo-delete-confirm-btn').on('click', function () {
                self.confirmDelete();
            });

            $('#wo-delete-cancel-btn').on('click', function () {
                self.hideDeleteModal();
            });

            // Area collapse toggle
            $(document).on('click', '.wo-area-collapse-btn', function () {
                self.toggleAreaCollapse($(this));
            });
        },

        // ============================================================
        // CRITICAL: Drag-and-Drop with jQuery UI Sortable
        // ============================================================
        initSortable: function () {
            var self = this;

            // Initialize sortable for areas (drag entire sections)
            this.elements.areasContainer.sortable({
                items: '.wo-area-card',
                handle: '.wo-area-drag-handle',
                placeholder: 'wo-area-card ui-sortable-placeholder',
                tolerance: 'pointer',
                cursor: 'grabbing',
                opacity: 0.8,
                revert: 200,
                scroll: true,
                scrollSensitivity: 40,
                scrollSpeed: 20,
                disabled: true, // Disabled by default, enabled in edit mode

                start: function (event, ui) {
                    ui.item.addClass('is-dragging');
                    ui.placeholder.height(ui.item.outerHeight());
                },

                stop: function (event, ui) {
                    ui.item.removeClass('is-dragging');
                    self.handleAreaReorder();
                }
            });

            // Initialize sortable for line items within each area
            this.elements.lineItemsTables.each(function () {
                var $tbody = $(this);
                var areaId = $tbody.data('area-id');

                $tbody.sortable({
                    items: '.wo-line-item-row:not(.is-deleted)',
                    handle: '.wo-drag-handle',
                    placeholder: 'wo-line-item-row ui-sortable-placeholder',
                    tolerance: 'pointer',
                    cursor: 'grabbing',
                    opacity: 0.8,
                    revert: 150,
                    scroll: true,
                    scrollSensitivity: 40,
                    scrollSpeed: 20,
                    disabled: true, // Disabled by default, enabled in edit mode
                    connectWith: false, // Don't allow moving between areas for Phase 1

                    start: function (event, ui) {
                        ui.item.addClass('is-dragging');
                        ui.placeholder.height(ui.item.outerHeight());
                    },

                    stop: function (event, ui) {
                        ui.item.removeClass('is-dragging');
                        self.handleLineItemReorder($tbody, areaId);
                    }
                });
            });

            console.log('Sortable initialized for areas and line items');
        },

        // Enable sortable when entering edit mode
        enableSortable: function () {
            this.elements.areasContainer.sortable('enable');
            this.elements.lineItemsTables.sortable('enable');
            console.log('Sortable enabled');
        },

        // Disable sortable when exiting edit mode
        disableSortable: function () {
            this.elements.areasContainer.sortable('disable');
            this.elements.lineItemsTables.sortable('disable');
            console.log('Sortable disabled');
        },

        // Handle area reorder after drag-drop
        handleAreaReorder: function () {
            var self = this;
            var areaIds = [];

            this.elements.areasContainer.find('.wo-area-card').each(function (index) {
                var areaId = $(this).data('area-id');
                areaIds.push(areaId);
            });

            console.log('Areas reordered:', areaIds);

            // Send to server
            this.apiRequest('reorderAreas', {
                workOrderId: this.config.workOrderId,
                areaIds: areaIds
            }, function (response) {
                if (response.success) {
                    self.showToast('Areas reordered successfully', 'success');
                    self.markAsChanged();
                } else {
                    self.showToast('Failed to reorder areas: ' + response.message, 'error');
                    // Revert the order
                    location.reload();
                }
            });
        },

        // Handle line item reorder after drag-drop
        handleLineItemReorder: function ($tbody, areaId) {
            var self = this;
            var lineItemIds = [];

            $tbody.find('.wo-line-item-row:not(.is-deleted)').each(function (index) {
                var lineItemId = $(this).data('line-item-id');
                lineItemIds.push(lineItemId);
            });

            console.log('Line items reordered in area ' + areaId + ':', lineItemIds);

            // Send to server
            this.apiRequest('reorderLineItems', {
                workOrderId: this.config.workOrderId,
                areaId: areaId,
                lineItemIds: lineItemIds
            }, function (response) {
                if (response.success) {
                    self.showToast('Line items reordered', 'success');
                    self.markAsChanged();
                } else {
                    self.showToast('Failed to reorder: ' + response.message, 'error');
                }
            });
        },

        // ============================================================
        // Edit Mode
        // ============================================================
        enterEditMode: function () {
            this.state.isEditMode = true;
            this.elements.page.addClass('wo-edit-mode');
            this.elements.editModeBtn.hide();
            this.elements.saveModeBtn.show();
            this.elements.cancelModeBtn.show();

            // Enable drag-and-drop
            this.enableSortable();

            console.log('Entered edit mode');
        },

        exitEditMode: function () {
            this.state.isEditMode = false;
            this.elements.page.removeClass('wo-edit-mode');
            this.elements.editModeBtn.show();
            this.elements.saveModeBtn.hide();
            this.elements.cancelModeBtn.hide();

            // Disable drag-and-drop
            this.disableSortable();

            console.log('Exited edit mode');
        },

        cancelEditMode: function () {
            if (this.state.hasUnsavedChanges) {
                if (!confirm('You have unsaved changes. Are you sure you want to cancel?')) {
                    return;
                }
            }

            // Reload the page to revert changes
            location.reload();
        },

        // ============================================================
        // Field Editing
        // ============================================================
        handleFieldChange: function ($input) {
            var self = this;
            var $row = $input.closest('.wo-line-item-row');
            var lineItemId = $row.data('line-item-id');
            var fieldName = $input.data('field');
            var newValue = $input.val();
            var originalValue = $input.data('original-value');

            // Validate
            if (!this.validateFieldValue(fieldName, newValue)) {
                $input.val(originalValue);
                return;
            }

            // Check if value actually changed
            if (newValue === String(originalValue)) {
                return;
            }

            console.log('Field changed:', fieldName, 'from', originalValue, 'to', newValue);

            // Mark as modified
            $input.addClass('is-modified');
            $input.data('original-value', newValue);

            // Update display value
            $row.find('.wo-field-value[data-field="' + fieldName + '"]').text(
                this.formatFieldValue(fieldName, newValue)
            );

            // Update total hours if prep or working changed
            if (fieldName === 'PrepHrs' || fieldName === 'WorkingHrs') {
                this.updateRowTotalHours($row);
            }

            // Send to server
            this.apiRequest('updateLineItem', {
                workOrderId: this.config.workOrderId,
                lineItemId: lineItemId,
                field: fieldName,
                value: newValue
            }, function (response) {
                if (response.success) {
                    // Update totals
                    if (response.totals) {
                        self.updateAreaTotals($row.closest('.wo-area-card'), response.totals);
                        self.updateGrandTotals(response.totals);
                    }
                    self.markAsChanged();
                } else {
                    self.showToast('Failed to update: ' + response.message, 'error');
                    $input.val(originalValue);
                }
            });
        },

        handleAreaNameChange: function ($input) {
            var self = this;
            var $card = $input.closest('.wo-area-card');
            var areaId = $card.data('area-id');
            var newName = $input.val().trim();
            var originalName = $input.data('original-value');

            if (!newName) {
                $input.val(originalName);
                this.showToast('Area name cannot be empty', 'error');
                return;
            }

            if (newName === originalName) {
                return;
            }

            console.log('Area name changed:', originalName, 'to', newName);

            // Update display
            $card.find('.wo-area-title').text(newName);
            $input.data('original-value', newName);

            // Send to server
            this.apiRequest('updateAreaName', {
                workOrderId: this.config.workOrderId,
                areaId: areaId,
                customAreaName: newName
            }, function (response) {
                if (response.success) {
                    self.showToast('Area name updated', 'success');
                    self.markAsChanged();
                } else {
                    self.showToast('Failed to update area name: ' + response.message, 'error');
                    $input.val(originalName);
                    $card.find('.wo-area-title').text(originalName);
                }
            });
        },

        revertFieldValue: function ($input) {
            var originalValue = $input.data('original-value');
            $input.val(originalValue);
        },

        validateFieldValue: function (fieldName, value) {
            if (fieldName === 'PrepHrs' || fieldName === 'WorkingHrs') {
                var numValue = parseFloat(value);
                if (isNaN(numValue) || numValue < 0 || numValue > 24) {
                    this.showToast('Hours must be between 0 and 24', 'error');
                    return false;
                }
            }

            if (fieldName === 'Coats') {
                var intValue = parseInt(value);
                if (isNaN(intValue) || intValue < 0 || intValue > 100) {
                    this.showToast('Coats must be between 0 and 100', 'error');
                    return false;
                }
            }

            return true;
        },

        formatFieldValue: function (fieldName, value) {
            if (fieldName === 'PrepHrs' || fieldName === 'WorkingHrs') {
                return parseFloat(value).toFixed(2);
            }
            return value;
        },

        // ============================================================
        // Totals Calculation
        // ============================================================
        updateRowTotalHours: function ($row) {
            var prepHrs = parseFloat($row.find('.wo-field-input[data-field="PrepHrs"]').val()) || 0;
            var workingHrs = parseFloat($row.find('.wo-field-input[data-field="WorkingHrs"]').val()) || 0;
            var totalHrs = prepHrs + workingHrs;

            $row.find('.wo-total-hrs').text(totalHrs.toFixed(2));
        },

        updateAreaTotals: function ($card, totals) {
            if (!totals) return;

            $card.find('.wo-area-prep-total').text(totals.areaPrepHours.toFixed(2));
            $card.find('.wo-area-working-total').text(totals.areaWorkingHours.toFixed(2));
            $card.find('.wo-area-total').text(totals.areaTotalHours.toFixed(2));
        },

        updateGrandTotals: function (totals) {
            if (!totals) return;

            this.elements.grandTotals.prep.text(totals.grandPrepHours.toFixed(2));
            this.elements.grandTotals.working.text(totals.grandWorkingHours.toFixed(2));
            this.elements.grandTotals.total.text(totals.grandTotalHours.toFixed(2));
        },

        recalculateAllTotals: function () {
            var self = this;
            var grandPrep = 0;
            var grandWorking = 0;
            var grandTotal = 0;

            $('.wo-area-card').each(function () {
                var $card = $(this);
                var areaPrep = 0;
                var areaWorking = 0;
                var areaTotal = 0;

                $card.find('.wo-line-item-row:not(.is-deleted)').each(function () {
                    var $row = $(this);
                    var prep = parseFloat($row.find('.wo-field-input[data-field="PrepHrs"]').val()) || 0;
                    var working = parseFloat($row.find('.wo-field-input[data-field="WorkingHrs"]').val()) || 0;

                    areaPrep += prep;
                    areaWorking += working;
                    areaTotal += (prep + working);
                });

                // Update area totals
                $card.find('.wo-area-prep-total').text(areaPrep.toFixed(2));
                $card.find('.wo-area-working-total').text(areaWorking.toFixed(2));
                $card.find('.wo-area-total').text(areaTotal.toFixed(2));

                grandPrep += areaPrep;
                grandWorking += areaWorking;
                grandTotal += areaTotal;
            });

            // Update grand totals
            this.elements.grandTotals.prep.text(grandPrep.toFixed(2));
            this.elements.grandTotals.working.text(grandWorking.toFixed(2));
            this.elements.grandTotals.total.text(grandTotal.toFixed(2));
        },

        // ============================================================
        // Delete Functionality
        // ============================================================
        showDeleteConfirmation: function ($row) {
            var itemName = $row.find('.wo-item-name').text();
            var lineItemId = $row.data('line-item-id');

            this.state.pendingDelete = {
                $row: $row,
                lineItemId: lineItemId,
                itemName: itemName
            };

            $('#wo-delete-item-name').text(itemName);
            this.elements.deleteModal.addClass('is-visible');
        },

        hideDeleteModal: function () {
            this.elements.deleteModal.removeClass('is-visible');
            this.state.pendingDelete = null;
        },

        confirmDelete: function () {
            var self = this;
            var pending = this.state.pendingDelete;

            if (!pending) return;

            this.hideDeleteModal();

            // Send delete request
            this.apiRequest('deleteLineItem', {
                workOrderId: this.config.workOrderId,
                lineItemId: pending.lineItemId
            }, function (response) {
                if (response.success) {
                    // Animate row removal
                    pending.$row.addClass('is-deleted').slideUp(300, function () {
                        // Update totals after removal
                        self.recalculateAllTotals();
                    });

                    self.showToast('Item deleted', 'success');
                    self.markAsChanged();
                } else {
                    self.showToast('Failed to delete: ' + response.message, 'error');
                }
            });
        },

        // ============================================================
        // Area Collapse
        // ============================================================
        toggleAreaCollapse: function ($btn) {
            var $card = $btn.closest('.wo-area-card');
            var $body = $card.find('.wo-area-body');
            var $icon = $btn.find('svg, i');

            $body.toggleClass('collapsed');

            // Rotate icon
            if ($body.hasClass('collapsed')) {
                $icon.css('transform', 'rotate(-90deg)');
            } else {
                $icon.css('transform', 'rotate(0)');
            }
        },

        // ============================================================
        // Save All Changes
        // ============================================================
        saveAllChanges: function () {
            var self = this;

            // Collect all current state
            var saveData = this.collectSaveData();

            this.showLoading();

            this.apiRequest('saveChanges', saveData, function (response) {
                self.hideLoading();

                if (response.success) {
                    self.showToast('All changes saved successfully', 'success');
                    self.state.hasUnsavedChanges = false;
                    self.elements.unsavedIndicator.removeClass('is-visible');
                    self.exitEditMode();
                } else {
                    self.showToast('Failed to save: ' + response.message, 'error');
                }
            });
        },

        collectSaveData: function () {
            var data = {
                workOrderId: this.config.workOrderId,
                areas: []
            };

            $('.wo-area-card').each(function (areaIndex) {
                var $card = $(this);
                var areaId = $card.data('area-id');

                var areaData = {
                    areaId: areaId,
                    customAreaName: $card.find('.wo-area-title-input').val(),
                    sortOrder: areaIndex + 1,
                    lineItems: []
                };

                $card.find('.wo-line-item-row').each(function (itemIndex) {
                    var $row = $(this);
                    var lineItemId = $row.data('line-item-id');

                    var lineItemData = {
                        lineItemId: lineItemId,
                        prepHrs: parseFloat($row.find('.wo-field-input[data-field="PrepHrs"]').val()) || 0,
                        workingHrs: parseFloat($row.find('.wo-field-input[data-field="WorkingHrs"]').val()) || 0,
                        unit: $row.find('.wo-field-input[data-field="Unit"]').val() || '',
                        coats: parseInt($row.find('.wo-field-input[data-field="Coats"]').val()) || 0,
                        sortOrder: itemIndex + 1,
                        isDeleted: $row.hasClass('is-deleted')
                    };

                    areaData.lineItems.push(lineItemData);
                });

                data.areas.push(areaData);
            });

            return data;
        },

        // ============================================================
        // Change Tracking
        // ============================================================
        markAsChanged: function () {
            this.state.hasUnsavedChanges = true;
            this.elements.unsavedIndicator.addClass('is-visible');
        },

        setupBeforeUnload: function () {
            var self = this;

            $(window).on('beforeunload', function (e) {
                if (self.state.hasUnsavedChanges && self.state.isEditMode) {
                    var message = 'You have unsaved changes. Are you sure you want to leave?';
                    e.returnValue = message;
                    return message;
                }
            });
        },

        // ============================================================
        // API Requests
        // ============================================================
        apiRequest: function (endpoint, data, callback) {
            var self = this;
            var url = this.config.apiEndpoints[endpoint];

            $.ajax({
                url: url,
                type: 'POST',
                contentType: 'application/json',
                data: JSON.stringify(data),
                headers: {
                    'RequestVerificationToken': this.config.antiForgeryToken
                },
                success: function (response) {
                    if (callback) callback(response);
                },
                error: function (xhr, status, error) {
                    console.error('API Error:', status, error);
                    if (callback) {
                        callback({
                            success: false,
                            message: 'Network error. Please try again.'
                        });
                    }
                }
            });
        },

        // ============================================================
        // UI Feedback
        // ============================================================
        showToast: function (message, type) {
            var $toast = this.elements.toast;
            $toast
                .removeClass('wo-toast-success wo-toast-error')
                .addClass('wo-toast-' + type)
                .text(message)
                .addClass('is-visible');

            setTimeout(function () {
                $toast.removeClass('is-visible');
            }, 3000);
        },

        showLoading: function () {
            // Add loading overlay
            if (!$('#wo-loading-overlay').length) {
                $('body').append(
                    '<div id="wo-loading-overlay" style="' +
                    'position: fixed; top: 0; left: 0; right: 0; bottom: 0; ' +
                    'background: rgba(255,255,255,0.8); z-index: 9999; ' +
                    'display: flex; align-items: center; justify-content: center;">' +
                    '<div class="wo-spinner"></div><span style="margin-left: 12px;">Saving...</span>' +
                    '</div>'
                );
            }
            $('#wo-loading-overlay').show();
        },

        hideLoading: function () {
            $('#wo-loading-overlay').hide();
        }
    };

    // ============================================================
    // jQuery Plugin
    // ============================================================
    $.fn.workOrderEditor = function (options) {
        return this.each(function () {
            WorkOrderEditor.init(options);
        });
    };

    // Expose globally for debugging
    window.WorkOrderEditor = WorkOrderEditor;

})(jQuery);
