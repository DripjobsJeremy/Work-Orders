# Work Order Customization - Developer Handoff

## Overview

This document provides everything needed to implement the Work Order Editor features in DripJobs V2. The prototype demonstrates a complete work order management interface for painting contractors.

**Live Prototype:** https://dripjobs-work-orders.netlify.app/
**Source:** `WorkOrderCustomization/demo/index.html` (single-file prototype)

---

## Tech Stack Used in Prototype

| Component | Library/Framework |
|-----------|-------------------|
| CSS Framework | Bootstrap 4.6.2 |
| JavaScript | jQuery 3.6.0 |
| Drag & Drop | jQuery UI (Sortable) |
| Icons | Inline SVG (Feather-style) |

**Note:** The V2 implementation should use the project's existing tech stack. This prototype uses jQuery for rapid prototyping only.

---

## Design System

### Color Variables

```css
:root {
    /* Primary (Purple) */
    --dj-primary: #7C3AED;
    --dj-primary-dark: #6D28D9;
    --dj-primary-light: #A78BFA;
    --dj-primary-bg: #F3F0FF;
    --dj-primary-border: #DDD6FE;

    /* Status Colors */
    --dj-success: #10B981;
    --dj-success-bg: #D1FAE5;
    --dj-danger: #EF4444;
    --dj-danger-bg: #FEE2E2;
    --dj-warning: #F59E0B;
    --dj-warning-bg: #FEF3C7;

    /* Gray Scale */
    --dj-gray-50: #F9FAFB;
    --dj-gray-100: #F3F4F6;
    --dj-gray-200: #E5E7EB;
    --dj-gray-300: #D1D5DB;
    --dj-gray-400: #9CA3AF;
    --dj-gray-500: #6B7280;
    --dj-gray-600: #4B5563;
    --dj-gray-700: #374151;
    --dj-gray-800: #1F2937;

    /* Layout */
    --dj-touch-target: 48px;
    --dj-border-radius: 6px;
}
```

---

## Feature Breakdown

### 1. Edit Mode Toggle

**Behavior:**
- Page has two states: View Mode and Edit Mode
- Toggle via "Edit" / "Save" button in header
- Edit mode reveals: drag handles, inline editors, editable fields

**Implementation:**
```javascript
// Add/remove class on page container
$('.wo-edit-page').toggleClass('wo-edit-mode');
```

**CSS Pattern:**
```css
/* Hidden by default */
.wo-drag-handle { display: none; }

/* Visible in edit mode */
.wo-edit-mode .wo-drag-handle { display: flex; }
```

---

### 2. Project Timeline

**Structure:**
- 5 fixed milestones: Created, Accepted, Scheduled, Started, Completed
- Progress bar fills based on completed stages
- "Started" and "Completed" have inline date pickers

**Milestone States:**
| Class | Description | Dot Style |
|-------|-------------|-----------|
| `.is-complete` | Past stage | Purple fill + checkmark |
| `.is-complete-final` | Completed stage | Green fill + checkmark |
| `.is-current` | Active stage | Purple border, white fill |
| `.is-pending` | Future stage | Gray border, white fill |

**Date Editing (Started/Completed):**
```html
<div class="wo-milestone is-pending is-editable" data-milestone="started">
    <div class="wo-milestone-dot"></div>
    <span class="wo-milestone-label">Started</span>
    <span class="wo-milestone-date">Set Date</span>
    <input type="date" class="wo-milestone-date-input" />
</div>
```

**Behavior:**
- When "Started" date is set: milestone gets blue dot with checkmark
- When "Completed" date is set: milestone gets green dot with checkmark
- Progress bar updates automatically

---

### 3. Work Order Versions (Crew Tabs)

**Purpose:** Create filtered views of the work order for different crews.

**Structure:**
```html
<div class="wo-crew-tabs">
    <button class="wo-crew-tab is-active" data-crew-id="all">
        <span>Master (All Items)</span>
        <span class="wo-crew-tab-count">6</span>
    </button>
    <button class="wo-crew-tab" data-crew-id="painting">
        <span>Painting Crew</span>
        <span class="wo-crew-tab-count">4</span>
    </button>
    <button class="wo-crew-add-btn">+ New Crew WO</button>
</div>
```

**Behavior:**
- Master WO shows all items
- Crew-specific WOs filter line items by assignment
- Each version can be sent separately

---

### 4. Display Options (Toggles)

| Toggle | Effect |
|--------|--------|
| Show Hours | Hide/show Prep Hrs, Working Hrs, Total Hrs columns |
| Show Totals | Hide/show section totals and grand totals |
| Show Product Details | Hide/show product info under line items |

**Implementation:**
```javascript
// Toggle hours visibility
$('.wo-edit-page').toggleClass('wo-hours-hidden');
```

```css
.wo-hours-hidden .wo-col-prep,
.wo-hours-hidden .wo-col-working,
.wo-hours-hidden .wo-col-total {
    display: none;
}
```

---

### 5. Area/Section Cards

**Structure:**
- Collapsible cards containing line items
- Drag-and-drop reordering (Edit Mode only)
- Editable area names
- Package badge indicator
- Change Order badge (for items added via CO)

**Data Attributes:**
```html
<div class="wo-area-card" data-area-id="1">
```

**Key Features:**
- Collapse/expand with chevron button
- Area title inline editing
- Section totals in table footer (Prep, Working, Total hrs)

---

### 6. Line Items Table

**Columns:**
| Column | Class | Editable | Notes |
|--------|-------|----------|-------|
| Drag Handle | `.wo-col-drag` | N/A | 6-dot grip icon |
| Item | `.wo-col-item` | No | Name + product details |
| Prep Hrs | `.wo-col-prep` | Yes | Number input, step 0.25 |
| Working Hrs | `.wo-col-working` | Yes | Number input, step 0.25 |
| Total Hrs | `.wo-col-total` | No | Auto-calculated |
| Unit | `.wo-col-unit` | Yes | Number + unit label |
| Coats | `.wo-col-coats` | Yes | Integer input |
| Actions | `.wo-col-actions` | N/A | (Reserved) |

**Column Widths:**
```css
.wo-col-drag { width: 40px; }
.wo-col-item { /* flex: 1 */ }
.wo-col-prep { width: 100px; }
.wo-col-working { width: 100px; }
.wo-col-total { width: 100px; }
.wo-col-unit { width: 90px; }
.wo-col-coats { width: 70px; }
.wo-col-actions { width: 48px; }
```

**Inline Editing Pattern:**
```html
<td class="wo-col-prep wo-editable-field">
    <!-- Display value (View Mode) -->
    <span class="wo-field-value">
        <span class="wo-field-number">0.50</span>
    </span>
    <!-- Input (Edit Mode) -->
    <div class="wo-field-edit-wrapper">
        <input type="number" class="wo-field-input"
               step="0.25" min="0" max="24"
               value="0.50" data-original-value="0.50" />
    </div>
</td>
```

**Row Types:**
| Class | Description |
|-------|-------------|
| `.wo-line-item-row` | Standard item |
| `.wo-package-item` | Part of a package |
| `.wo-change-order-item` | Added via change order |

---

### 7. Change Order Indicators

**Area-level badge:**
```html
<span class="wo-change-order-badge" title="Added via Change Order">
    <svg>...</svg> Change Order
</span>
```

**Line item indicator:**
```html
<tr class="wo-line-item-row wo-change-order-item"
    data-change-order-date="01/26/2026">
```

**Styling:**
- Orange left border on change order items
- "CO" badge appears after item name
- Change order date shown on hover

---

### 8. Crew Notes

**Structure:**
```html
<div class="wo-crew-notes">
    <!-- View Mode -->
    <div class="wo-crew-notes-content">Note text here...</div>
    <!-- Edit Mode -->
    <textarea class="wo-crew-notes-textarea">Note text here...</textarea>
</div>
```

**Behavior:**
- View Mode: Shows static text
- Edit Mode: Shows editable textarea
- Notes can be crew-specific when viewing filtered WO

---

### 9. Media/File Attachments

**Structure:**
```html
<div class="wo-media-item" data-media-id="1">
    <img src="..." class="wo-media-thumb" />
    <div class="wo-media-toggle">
        <svg><!-- checkmark --></svg>
    </div>
</div>
```

**Behavior:**
- Click to toggle visibility in Edit Mode
- Hidden items show with `.is-hidden` class (opacity reduced)
- Supports images and file attachments (PDF, etc.)

---

### 10. Grand Totals

**Structure:**
```html
<div class="wo-grand-totals">
    <div class="wo-grand-totals-grid">
        <div class="wo-grand-total-item">
            <div class="wo-grand-total-label">Total Prep Hours</div>
            <div class="wo-grand-total-value" id="wo-grand-prep-hours">4.00</div>
        </div>
        <!-- Working Hours -->
        <!-- Grand Total (with .is-primary class) -->
    </div>
</div>
```

**Calculation:**
- Sum of all section totals
- Updates in real-time when hours change

---

## Mobile Responsiveness

**Breakpoint:** 768px

### Mobile Table Layout
- Table transforms to stacked card layout
- Each row becomes a card with label/value pairs
- Drag handles hidden on mobile (tap-and-hold for reorder)

### Mobile Timeline
- All 5 milestones fit on single line
- Smaller font sizes (9px label, 8px date)

### Key CSS:
```css
@media (max-width: 767px) {
    .wo-line-items-table thead { display: none; }
    .wo-line-item-row {
        display: block;
        /* Card-style layout */
    }
    .wo-editable-field::before {
        content: attr(data-label);
        /* Shows column label */
    }
}
```

---

## JavaScript Functions Reference

| Function | Purpose |
|----------|---------|
| `init()` | Initialize editor, bind events, setup sortable |
| `toggleEditMode()` | Switch between view/edit modes |
| `handleFieldChange()` | Process inline field edits, update totals |
| `updateAreaTotals()` | Recalculate section totals |
| `updateGrandTotals()` | Recalculate overall totals |
| `handleMilestoneDateChange()` | Process timeline date edits |
| `updateTimelineProgress()` | Update progress bar fill |
| `handleSettingToggle()` | Toggle display options |
| `saveAreaName()` | Save edited area title |
| `toggleAreaCollapse()` | Expand/collapse area sections |
| `handleMediaToggle()` | Toggle media visibility |
| `showToast()` | Display feedback messages |

---

## Data Model Suggestions

### WorkOrder
```typescript
interface WorkOrder {
    id: string;
    jobId: string;
    status: 'draft' | 'sent' | 'in_progress' | 'completed';
    timeline: {
        created: Date;
        accepted?: Date;
        scheduledStart?: Date;
        scheduledEnd?: Date;
        started?: Date;
        completed?: Date;
    };
    crewNotes: string;
    areas: Area[];
    changeOrders: ChangeOrder[];
    settings: {
        showHours: boolean;
        showTotals: boolean;
        showProducts: boolean;
    };
}
```

### Area
```typescript
interface Area {
    id: string;
    name: string;
    sortOrder: number;
    packageId?: string;
    packageName?: string;
    lineItems: LineItem[];
    isChangeOrder?: boolean;
}
```

### LineItem
```typescript
interface LineItem {
    id: string;
    areaId: string;
    name: string;
    type: 'Walls' | 'Ceiling' | 'Trim' | 'Doors' | 'Windows' | etc;
    product?: string;
    prepHours: number;
    workingHours: number;
    unitQuantity: number;
    unitType: 'sqft' | 'lft' | 'each' | etc;
    coats: number;
    sortOrder: number;
    packageId?: string;
    changeOrderId?: string;
    changeOrderDate?: Date;
    crewAssignment?: string;
}
```

### CrewVersion
```typescript
interface CrewVersion {
    id: string;
    workOrderId: string;
    name: string;
    crewId?: string;
    lineItemIds: string[]; // Filtered subset of parent WO
    notes: string;
}
```

---

## API Endpoints Needed

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/work-orders/:id` | Fetch work order with all areas/items |
| PUT | `/api/work-orders/:id` | Update work order settings/timeline |
| PUT | `/api/work-orders/:id/areas/reorder` | Reorder areas |
| PUT | `/api/work-orders/:id/areas/:areaId` | Update area name |
| PUT | `/api/work-orders/:id/line-items/:id` | Update line item values |
| PUT | `/api/work-orders/:id/line-items/reorder` | Reorder items within area |
| POST | `/api/work-orders/:id/crew-versions` | Create crew-specific WO |
| PUT | `/api/work-orders/:id/media/:mediaId/visibility` | Toggle media visibility |

---

## Testing Checklist

### Edit Mode
- [ ] Edit button toggles to Save button
- [ ] Drag handles appear on areas and line items
- [ ] Field inputs become editable
- [ ] Area names become editable
- [ ] Crew notes textarea appears

### Timeline
- [ ] Progress bar fills correctly based on stage
- [ ] Clicking Started/Completed shows date picker
- [ ] Setting Started date turns dot blue with checkmark
- [ ] Setting Completed date turns dot green with checkmark
- [ ] Change order pills display correctly

### Line Items
- [ ] Prep + Working = Total calculation works
- [ ] Section totals update on field change
- [ ] Grand totals update on field change
- [ ] Drag-and-drop reordering works
- [ ] Change order items show orange border and badge

### Display Options
- [ ] Toggle Hours hides/shows hour columns
- [ ] Toggle Totals hides/shows totals sections
- [ ] Toggle Products hides/shows product details

### Mobile
- [ ] Table converts to card layout
- [ ] All timeline milestones on one line
- [ ] Touch targets are 48px minimum
- [ ] No horizontal scrolling

---

## Files Reference

| File | Description |
|------|-------------|
| `demo/index.html` | Complete prototype (HTML + CSS + JS) |
| `_redirects` | Netlify routing config |
| `DEVELOPER_HANDOFF.md` | This document |

---

## Questions for Product/Design

1. Should line item edits auto-save or require explicit save?
2. How should crew version filtering persist?
3. What permissions control who can edit vs view?
4. Should timeline dates sync with job scheduling system?
5. How do change order approvals flow into the work order?

---

## Contact

For prototype questions or clarifications, refer to the git history in the `WorkOrderCustomization` directory or the live demo at https://dripjobs-work-orders.netlify.app/
