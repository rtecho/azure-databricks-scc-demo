/**
 * app.js - Main JavaScript for Azure Databricks Secure Cluster Connectivity Demo
 *
 * Handles:
 *   1. Sidebar toggle (mobile hamburger menu)
 *   2. Active page highlight in sidebar navigation
 *   3. Tab navigation within content pages
 *   4. Smooth scrolling for anchor links
 *   5. Checklist interactivity (toggle completed state)
 */

/* ============================================================
   1. Sidebar Toggle (mobile hamburger menu)
   ============================================================ */

/**
 * Initialises the mobile sidebar behaviour.
 * Opens/closes the sidebar and overlay when the hamburger button is clicked
 * or the overlay is tapped, and auto-closes when the viewport grows past the
 * mobile breakpoint.
 */
function initSidebarToggle() {
    const hamburger = document.getElementById('hamburgerBtn');
    const sidebar = document.getElementById('sidebar');
    const overlay = document.getElementById('sidebarOverlay');

    function openSidebar() {
        sidebar.classList.add('open');
        overlay.classList.add('active');
        document.body.style.overflow = 'hidden';
    }

    function closeSidebar() {
        sidebar.classList.remove('open');
        overlay.classList.remove('active');
        document.body.style.overflow = '';
    }

    if (hamburger) hamburger.addEventListener('click', openSidebar);
    if (overlay) overlay.addEventListener('click', closeSidebar);

    // Close the sidebar automatically when the window is resized to desktop width
    window.addEventListener('resize', function () {
        if (window.innerWidth > 960) closeSidebar();
    });
}

/* ============================================================
   2. Active Page Highlight
   ============================================================ */

/**
 * Detects the current page from the URL and adds the 'active' class to the
 * matching sidebar navigation link so users can see where they are.
 */
function initActivePageHighlight() {
    const currentPage = window.location.pathname.split('/').pop() || 'index.html';
    const navLinks = document.querySelectorAll('.sidebar-nav a, #sidebar a');

    navLinks.forEach(function (link) {
        const href = link.getAttribute('href');
        if (href === currentPage) {
            link.classList.add('active');
        } else {
            link.classList.remove('active');
        }
    });
}

/* ============================================================
   3. Tab Navigation
   ============================================================ */

/**
 * Wires up every `.tab-nav` group on the page so that clicking a tab button
 * shows the corresponding tab pane and hides the others.
 */
function initTabs() {
    document.querySelectorAll('.tab-nav').forEach(function (tabNav) {
        var buttons = tabNav.querySelectorAll('button');
        var container = tabNav.closest('.tab-container') || tabNav.parentElement;
        var panes = container.querySelectorAll('.tab-pane, .tab-panel');

        buttons.forEach(function (btn, index) {
            btn.addEventListener('click', function () {
                // Deactivate all buttons and panes
                buttons.forEach(function (b) { b.classList.remove('active'); });
                panes.forEach(function (p) { p.classList.remove('active'); });

                // Activate the clicked button and its matching pane
                btn.classList.add('active');
                if (panes[index]) panes[index].classList.add('active');
            });
        });
    });
}

/* ============================================================
   4. Smooth Scroll for Anchor Links
   ============================================================ */

/**
 * Intercepts clicks on same-page anchor links (e.g. href="#section") and
 * smoothly scrolls to the target element instead of jumping instantly.
 */
function initSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach(function (anchor) {
        anchor.addEventListener('click', function (e) {
            var targetId = this.getAttribute('href');

            // Ignore empty fragment links
            if (!targetId || targetId === '#') return;

            var targetElement = document.querySelector(targetId);
            if (targetElement) {
                e.preventDefault();
                targetElement.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });

                // Update the URL hash without triggering a scroll jump
                if (history.pushState) {
                    history.pushState(null, null, targetId);
                }
            }
        });
    });
}

/* ============================================================
   5. Checklist Interactivity
   ============================================================ */

/**
 * Makes every checklist item toggleable.
 * Clicking an item adds or removes the 'completed' class so the UI can
 * visually distinguish finished items (e.g. strikethrough, colour change).
 */
function initChecklist() {
    var checklistItems = document.querySelectorAll(
        '.checklist-item, .checklist li, [data-checklist] li'
    );

    checklistItems.forEach(function (item) {
        item.addEventListener('click', function () {
            this.classList.toggle('completed');
        });

        // Allow keyboard activation for accessibility (Enter and Space)
        item.setAttribute('role', 'checkbox');
        item.setAttribute('aria-checked', 'false');
        item.setAttribute('tabindex', '0');

        item.addEventListener('keydown', function (e) {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                this.classList.toggle('completed');

                // Keep the aria-checked attribute in sync
                var isCompleted = this.classList.contains('completed');
                this.setAttribute('aria-checked', String(isCompleted));
            }
        });

        // Keep aria-checked in sync on click as well
        item.addEventListener('click', function () {
            var isCompleted = this.classList.contains('completed');
            this.setAttribute('aria-checked', String(isCompleted));
        });
    });
}

/* ============================================================
   6. Initialise Everything on DOMContentLoaded
   ============================================================ */

document.addEventListener('DOMContentLoaded', function () {
    initSidebarToggle();
    initActivePageHighlight();
    initTabs();
    initSmoothScroll();
    initChecklist();
});
