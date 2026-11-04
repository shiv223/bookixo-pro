/// Central user-facing copy, ready for localization.
abstract final class AppStrings {
  static const catalogueServices = 'Services';
  static const catalogueSubtitle = 'Browse the service catalog';
  static const catalogueEmpty = 'No services here yet.';
  static const serviceCategory = 'Category';
  static const shopUsers = 'Shop Users';
  static const shopUsersSubtitle = 'People at this salon';
  static const shopUsersEmpty = 'No shop users here yet.';
  static const userStatusUnknown = 'Active status unavailable';
  static const phoneNotProvided = 'Phone not provided';
  static const shopSettings = 'Shop Settings';
  static const shopSettingsSubtitle = 'Salon setup information';
  static const shopSettingsEmpty = 'No supported settings available.';
  static const workday = 'Workday';
  static const gstSettings = 'GST settings';
  static const bookingQr = 'Booking QR';
  static const paymentSettings = 'Payment settings';
  static const availableOnWeb = 'Available on Bookixo web';
  static const settingsWebBody =
      'View or change this setting on Bookixo web. Configuration is not available in the mobile app.';
  static const operations = 'Operations';
  static const operationsSubtitle = 'Queue and services';
  static const queueIdentityFallback = 'Shop team';
  static const dashboard = 'Dashboard';
  static const homeDashboard = 'Dashboard / KPI';
  static const welcomeBack = 'Welcome back';
  static const ownerRole = 'Owner';
  static const employeeRole = 'Employee';
  static String homeShop(String shop, String role) => '$shop · $role';
  static const dashboardSubtitle = "Today's performance";
  static const offers = 'Offers';
  static const offersSubtitle = 'Schedules & availability';
  static const offersNotice =
      'Create or edit offers and schedules on Bookixo web.';
  static const offersEmpty = 'No offers here. Create one on Bookixo web.';
  static const offersLoading = 'Loading offers…';
  static const offersUnavailable = 'We could not load offers. Please retry.';
  static const allOffers = 'All';
  static const openWebUnavailable = 'Open web — unavailable';
  static const noFilteredOffers = 'No offers in this filter.';
  static const off = 'Off';
  static const expired = 'Expired';
  static const upcoming = 'Upcoming';
  static const validityUnavailable = 'Validity unavailable';
  static const discountUnavailable = 'Discount unavailable';
  static const offLabel = 'OFF';
  static const flatOff = 'FLAT OFF';
  static const targetsResource = 'Targets';
  static const rulesResource = 'Schedules';
  static const noRules = 'No rules';
  static const ruleStatusUnavailable = 'Status unavailable';
  static const offersResource = 'Offers';
  static const resourcePending = 'Still loading. Details are incomplete.';
  static const resourceCap =
      'Incomplete: the 10-page limit was reached. Export is unavailable.';
  static const resourcePartial = 'Showing loaded data only.';
  static const invalidSchedule =
      'Some schedule rules could not be understood. Export is unavailable.';
  static const noScheduleRules = 'No schedule rules';
  static const schedulesIncomplete = 'Schedule details incomplete';
  static const noTargets = 'No targets set up yet. Set this up on Bookixo web.';
  static const offerMissing =
      'This offer is not available in the loaded offers.';
  static const exportUnavailable =
      'Share and Save image are unavailable until this offer and its details are valid and complete.';
  static const offNote =
      'This offer is off. Activation is available on Bookixo web.';
  static const expiredNote =
      'This offer has expired. Its cards cannot be exported.';
  static const upcomingNote =
      'This offer has not started yet. Its cards cannot be exported.';
  static const validityNote =
      'Validity dates are missing or invalid. Its cards cannot be exported.';
  static const overlapWarning = 'Another offer also applies to these services';
  static const allServices = 'On all services';
  static const comboPrefix = 'Combo: ';
  static const onPrefix = 'On ';
  static const andJoin = ' and ';
  static const orJoin = ' or ';
  static const neutralJoin = ', ';
  static const comboJoin = ' + ';
  static const share = 'Share';
  static const saveImage = 'Save image';
  static const imageSaved = 'Image saved to your gallery.';
  static const exportFailed = 'Could not export this card. Please try again.';
  static const galleryDenied =
      'Gallery access was not granted. Allow access in Settings and try Save image again.';
  static const galleryFull =
      'Not enough storage. Free some space and try again.';
  static const exportUnsupported =
      'Image export is not supported on this platform.';
  static const exportChanged =
      'This offer or your access changed. Reload details before exporting.';
  static const decorativeBarcode =
      'Decorative ticket stripes, not a redeemable code';
  static const weekdayShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const weekdayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const weekdaysLabel = 'Weekdays';
  static const weekendsLabel = 'Weekends';
  static String offersWithActiveRules(int count) =>
      '$count offers with active rules';
  static String filterUnavailable(String label) => '$label (—)';
  static String filterCount(String label, int count) => '$label ($count)';
  static String resourceNotice(String label, String notice) =>
      '$label: $notice';
  static String validityRange(DateTime start, DateTime end) =>
      '${offerDate(start)} – ${offerDate(end)}';
  static String timeWindow(String start, String end) => '$start to $end';
  static const loadMore = 'Load more';
  static const active = 'Active';
  static const inactive = 'Inactive';
  static const savingStatus = 'Saving status…';
  static const always = 'Always';
  static const weekly = 'Weekly';
  static const monthly = 'Monthly';
  static const date = 'Date';
  static const everyDay = 'Every day';
  static const scheduleUnavailable = 'Schedule unavailable';
  static const weekdays = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];
  static const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static String monthlyDay(int day) => 'Day $day of each month';
  static String offerDate(DateTime date) =>
      '${months[date.month - 1]} ${date.day}, ${date.year}';
  static String offerStatus(String title, String status) => '$title: $status';
  static const creditsPackages = 'Credits & Packages';
  static const membership = 'Membership';
  static const pending = 'Pending';
  static const inProgress = 'In progress';
  static const webOnly = 'Web only';
  static const currentlyWeb = 'Currently available on Bookixo web';
  static const logoUnavailable =
      'Shop logo unavailable. You can keep using Home or retry.';
  static const shopLogo = 'Shop logo';
  static const menuLoading = 'Loading your menu…';
  static const noAccess = 'No access';
  static const noAccessBody =
      'No mobile features are assigned. Refresh or contact your administrator.';
  static const refresh = 'Refresh';
  static String homeSwitchSalon(String salon) => 'Switch salon, $salon';
  static String shopHeaderTitle(String title, String abbreviation) =>
      abbreviation.isEmpty ? title : '$title · $abbreviation';
  static const staleMenu =
      'Showing saved access. We could not refresh your menu.';
  static const menuStorage =
      'Your latest access is shown, but could not be saved. Retry.';
  static const mockQueue =
      'Demo queue. Walk-in creation and starting bookings use sample data.';
  static const liveQueue = 'Live booking queue';
  static const queueRealtimeNotConfigured =
      'Live updates are not configured. Queue checks every 15 seconds.';
  static const queueRealtimeConnecting =
      'Connecting to live updates. Queue checks every 15 seconds until connected.';
  static const queueRealtimeDisconnected =
      'Live updates are disconnected. Queue checks every 15 seconds.';
  static const queueRealtimeUnavailable =
      'Live updates are unavailable. Queue checks every 15 seconds.';
  static const queueRealtimeConnected = 'Live queue updates are on.';
  static const queueRealtimeRetry = 'Retry connection';
  static const queueEmpty = 'No bookings in this tab.';
  static const queueWaitUnderMinute = 'Waiting less than a minute';
  static String queueWaitMinutes(int minutes) => 'Waiting $minutes min';
  static String queueWaitHours(int hours, int minutes) =>
      minutes == 0 ? 'Waiting $hours hr' : 'Waiting $hours hr $minutes min';
  static const addWalkIn = 'Add walk-in';
  static const newBooking = 'New booking';
  static const phoneNumber = 'Phone number';
  static const firstName = 'First name';
  static const lastName = 'Last name';
  static const gender = 'Gender';
  static const dateOfBirth = 'Date of birth';
  static const optional = 'Optional';
  static const createBooking = 'Create booking';
  static const startServiceImmediately = 'Start service right after creating';
  static const lookupInProgress = 'Looking up customer…';
  static const customerFound = 'Customer found. Details are editable.';
  static const newCustomerNotice =
      'A Bookixo account is created and an SMS invite is sent.';
  static const lookupFailedCreateAnyway =
      'Could not check this number. You can still create the booking.';
  static const phoneRequired = 'Enter a phone number to continue.';
  static const phoneInvalid = 'Enter a 10-digit phone number.';
  static const firstNameRequired = 'First name is required.';
  static const dateCannotBeFuture = 'Date of birth cannot be in the future.';
  static const pendingBookings = 'Pending';
  static const startBooking = 'Start';
  static const startingBooking = 'Starting…';
  static const bookingDetails = 'Booking details';
  static const mockBookingNotice =
      'MOCK DEMO ONLY · Booking details and draft actions use sample data.';
  static const pricingRequiresService =
      'Add a service to calculate the final amount.';
  static const bookingLineUnavailable =
      'A service or staff member is unavailable. Remove or replace the line before completing.';
  static const discardDraft = 'Discard draft';
  static const keepDraft = 'Keep draft';
  static const discardDraftConfirmation =
      'Discard all saved and unsaved service changes for this booking?';
  static const draftDiscarded = 'Draft discarded.';
  static const bookingDetailsUnavailable =
      'We could not load this booking. Please retry.';
  static const bookingServices = 'Services';
  static const serviceSearch = 'Search services';
  static const yourUsualServices = 'Your usual';
  static const alsoAddedServices = 'Also added';
  static const selectedServices = 'Selected services';
  static const noSelectedServices = 'No services selected yet.';
  static const serviceQuantity = 'Quantity';
  static const employeeDiscount = 'Discount %';
  static const discountInvalid =
      'Enter a valid discount within the shop limit.';
  static const alreadyAddedBy = 'Already added by';
  static const noMatchingServices = 'No matching services.';
  static const saveServices = 'Save services';
  static String saveServiceCount(int count) => 'Save $count services';
  static const servicesSaved = 'Services saved.';
  static const servicesSaveFailed =
      'Could not save services. Your changes are still here; retry.';
  static const bookingChanged =
      'Someone else just changed this booking. The latest draft was reloaded.';
  static const otherStaffLines = 'Services by other staff';
  static const ownerEditServices = 'Edit services';
  static const cancelEditing = 'Cancel editing';
  static const saveChanges = 'Save changes';
  static const paymentMode = 'Payment mode';
  static const paymentOption = 'Card option';
  static const paymentTransactionId = 'Transaction ID';
  static const paymentNote = 'Payment note';
  static const completePayment = 'Complete payment';
  static const retryCompletion = 'Retry completion';
  static const completionInProgress =
      'Completing payment… Please do not submit again.';
  static const completionFailed =
      'Could not complete this booking. Review the payment details and retry.';
  static const completionRecovery =
      'A previous attempt needs recovery. Retry completion to check its status.';
  static const bookingCompleted = 'Booking completed.';
  static const completionAwaitingPayment = 'Awaiting payment';
  static const cash = 'Cash';
  static const card = 'Card';
  static const upi = 'UPI';
  static const bookixo = 'Bookixo';
  static const pricingUnavailable =
      'Pricing is unavailable. Retry before completing payment.';
  static const refreshPricing = 'Refresh pricing';
  static const pricingOutOfDate =
      'Save service changes to refresh the pricing summary.';
  static const subtotal = 'Subtotal';
  static const employeeDiscountSummary = 'Employee discount';
  static const otherDiscounts = 'Other discounts';
  static const gst = 'GST';
  static const finalAmount = 'Final amount';
  static const appliedPricingRules = 'Applied pricing rules';
  static const membershipNoDiscount =
      'This membership did not apply a discount to these services.';
  static const servedBy = 'Served by';
  static const included = 'included';
  static const added = 'added';
  static const discountLabel = 'Discount';
  static const priceLabel = 'Price';
  static const noServicesToComplete =
      'Add at least one service before completing this booking.';
  static const unsupportedBookingRole =
      'This account cannot edit or complete bookings.';
  static const removeService = 'Remove service';
  static const decreaseQuantity = 'Decrease quantity';
  static const increaseQuantity = 'Increase quantity';
  static const readOnly = 'read-only';
  static String discountLimitHint(double limit) =>
      'Up to ${limit.toStringAsFixed(2)}%';
  static String appliedPricingRuleCount(int count) =>
      'Applied pricing rules ($count)';
  static String lineDiscount(double percent, String amount) =>
      'Discount ${percent.toStringAsFixed(2)}% · −$amount';
  static const withYou = 'With you';
  static const readyToPay = 'Ready to pay';
  static const awaitingPayment = 'Awaiting payment';
  static const sampleCustomerInProgress = 'Jamie Example';
  static const sampleLastName = 'Example';
  static const sampleStaff = 'Taylor';
  static const sampleWait = 'Waiting 8 min';
  static const bookingCreated = 'Booking created.';
  static const bookingStarted = 'Booking started.';
  static const startFailed =
      'Could not start this booking. Refresh and try again.';
  static const bookingCreateFailed =
      'Could not create the booking. Your details are still here; please retry.';
  static const queueToday = 'Today';
  static const genderMale = 'Male';
  static const genderFemale = 'Female';
  static const genderOther = 'Other';
  static const queueMonthsShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static String queueTodayDate(DateTime date) =>
      '$queueToday · ${queueMonthsShort[date.month - 1]} ${date.day}';
  static String queueTabLabel(String title, int? count) =>
      count == null ? '$title (—)' : '$title ($count)';
  static String queueCustomer(int number, String name) => '#$number · $name';
  static String withStaff(String firstName) => 'With $firstName';
  static const dashboardUnavailable =
      'We could not load this summary. Please try again.';
  static const dashboardTryAgain = 'Try again';
  static const dashboardToday = 'Today';
  static const dashboardSevenDays = '7 days';
  static const dashboardThirtyDays = '30 days';
  static const dashboardNetRevenue = 'NET REVENUE';
  static const dashboardPreviousPeriod = 'vs previous period';
  static const dashboardServiceRevenue = 'Service revenue';
  static const dashboardProductRevenue = 'Product revenue';
  static const dashboardAverageBill = 'Average bill';
  static const dashboardBills = 'Bills';
  static const dashboardTrend = 'Revenue trend';
  static const dashboardPaymentModes = 'Payment modes';
  static const dashboardAppointments = 'Appointments';
  static const dashboardTopServices = 'Top services';
  static const dashboardTopStaff = 'Top staff';
  static const dashboardLowStock = 'products low on stock';
  static const dashboardCurrentStock = 'Current stock';
  static const dashboardNoSales = 'No sales in this period';
  static const dashboardNoServices = 'No services in this period.';
  static const dashboardNoStaff = 'No staff activity in this period.';
  static const dashboardNoLowStock = 'No products are low on stock.';
  static const dashboardSeeAll = 'See all';
  static const dashboardClients = 'clients';
  static const dashboardRatingUnavailable = 'Rating unavailable';
  static const dashboardStaffServices = 'Services';
  static const dashboardLowStockProducts = 'Low stock products';
  static const dashboardMore = 'More';
  static const moreDashboard = dashboardMore;
  static const back = 'Back';
  static const dashboardServiceList = 'All services';
  static const dashboardStaffList = 'All staff';
  static const dashboardStaffDetail = 'Staff details';
  static const dashboardAverageBillLabel = 'Average bill';
  static const dashboardRevenue = 'Revenue';
  static const dashboardClientsLabel = 'Clients';
  static const dashboardRating = 'Rating';
  static String dashboardTopService(String service, String amount) =>
      '$service is your top service this period, bringing in $amount.';
  static const dashboardCreditsUsed = 'Credits used';
  static const dashboardPackagesSold = 'Packages sold';
  static const dashboardCreditsSold = 'Credits sold';
  static const dashboardMembershipsSold = 'Memberships sold';
  static const dashboardCompleted = 'Completed';
  static const dashboardPending = 'Pending';
  static const dashboardInProgress = 'In progress';
  static const dashboardCancelled = 'Cancelled';
  static const dashboardConfirmed = 'Confirmed';
  static const dashboardNoShow = 'No Show';
  static const dashboardUnknownStatus = 'Unknown status';
  static const dashboardStaffUnavailable = 'Staff';
  static const unavailableWeb = 'Open on web — unavailable';
  static const unavailableWebBody =
      'A web destination has not been configured. Contact your administrator.';
  static const offersBenefit =
      'Create and manage promotional offers on Bookixo web.';
  static const creditsBenefit =
      'Manage customer credits and service packages together on Bookixo web.';
  static const membershipBenefit =
      'Create membership plans and manage member benefits on Bookixo web.';
  static const sampleCustomer = 'Sample customer';
  static const bookingCustomerFallback = 'Customer';
  static const sampleService = 'Sample service';
  static const appName = 'Bookixo Pro';
  static const login = 'Sign in';
  static const loginSubtitle = 'Your salon, beautifully organised.';
  static const showPassword = 'Show password';
  static const hidePassword = 'Hide password';
  static const email = 'Email';
  static const loginIdentifier = 'Email or phone';
  static const identifierRequired =
      'Enter a valid email, a 10-digit Indian mobile, or a phone with country code.';
  static const switchSalon = 'Switch salon';
  static const chooseSalon = 'Choose salon';
  static const switchUnsaved = 'Discard unsaved work and switch salon?';
  static const switchDiscard = 'Discard and switch';
  static const switchCancel = 'Keep working';
  static const salonPreferenceFailed =
      'Your salon preference could not be restored or saved. You can still use this salon.';
  static const password = 'Password';
  static const emailRequired = 'Enter a valid email address.';
  static const passwordRequired = 'Enter your password.';
  static const retry = 'Retry';
  static const logout = 'Logout';
  static const loading = 'Checking your session…';
  static const signingIn = 'Signing in…';
  static const challenge =
      'Your account needs another sign-in step. Contact your administrator to continue.';
  static const unsupported = 'Account not supported';
  static const contactAdmin =
      'Contact your administrator for access to Bookixo Pro.';
  static const noShop = 'No shop assigned';
  static const shopLoading = 'Loading your shop…';
  static const ownerHome = 'Home';
  static const employeeScan = 'Scan';
  static const ownerPlaceholder =
      'Owner Home is ready. Operations will be available in a later update.';
  static const scanPlaceholder =
      'Attendance scanning will be available in a later update. Camera access is not enabled.';
  static const demo = 'MOCK DEMO ONLY';
  static const demoSwitch = 'Demo shop selection';
  static const selectedSuffix = ' ✓';
  static const network = 'No connection. Check your internet and try again.';
  static const unauthorized = 'Your session ended. Please sign in again.';
  static const forbidden =
      'You do not have access. Contact your administrator.';
  static const validation = 'Check your details and try again.';
  static const invalidCredentials =
      'Unable to sign in. Check your email and password.';
  static const server = 'The service is unavailable. Please try again.';
  static const unknown = 'Something went wrong. Please try again.';
  static const storage =
      'Unable to update your secure session. Retry or sign out.';
  static const contract =
      'We could not read your account details. Retry or contact your administrator.';
  static const config =
      'App configuration is missing or invalid. Contact your administrator.';
}
