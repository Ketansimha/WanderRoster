import { LightningElement } from 'lwc';

const DEFAULT_PAGE = 'employee';

const VALID_PAGES = [
    'employee',
    'finance',
    'manager'
];

const PAGE_TITLES = {
    employee: 'Employee Portal',
    finance: 'Finance Portal',
    manager: 'Manager Portal'
};

export default class WanderRosterApp extends LightningElement {
    // Default portal
    currentPage = DEFAULT_PAGE;

    // =========================================
    // PORTAL VISIBILITY
    // =========================================

    get isEmployee() {
        return this.currentPage === 'employee';
    }

    get isFinance() {
        return this.currentPage === 'finance';
    }

    get isManager() {
        return this.currentPage === 'manager';
    }

    // =========================================
    // PAGE HEADING
    // =========================================

    get pageTitle() {
        return PAGE_TITLES[this.currentPage] || PAGE_TITLES[DEFAULT_PAGE];
    }

    // =========================================
    // NAVIGATION BUTTON CLASSES
    // =========================================

    get employeeNavClass() {
        return this.getNavClass('employee');
    }

    get financeNavClass() {
        return this.getNavClass('finance');
    }

    get managerNavClass() {
        return this.getNavClass('manager');
    }

    // Return the correct class for the active page
    getNavClass(page) {
        return this.currentPage === page
            ? 'nav-item active'
            : 'nav-item';
    }

    // =========================================
    // NAVIGATION HANDLER
    // =========================================

    handleNavigation(event) {
        const selectedPage = event.currentTarget.dataset.page;

        // Ignore invalid navigation values
        if (!VALID_PAGES.includes(selectedPage)) {
            return;
        }

        // Avoid unnecessary state updates
        if (this.currentPage === selectedPage) {
            return;
        }

        // Change the active portal
        this.currentPage = selectedPage;
    }
}