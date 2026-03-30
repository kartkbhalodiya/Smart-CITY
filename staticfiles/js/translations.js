// Global translations for all pages
const globalTranslations = {
    'hi': {
        // Common UI elements
        'Submit': 'जमा करें', 'Cancel': 'रद्द करें', 'Save': 'सेव करें', 'Edit': 'संपादित करें', 'Delete': 'हटाएं', 'View': 'देखें', 'Back': 'वापस', 'Next': 'अगला', 'Previous': 'पिछला', 'Close': 'बंद करें', 'Search': 'खोजें', 'Filter': 'फिल्टर', 'Sort': 'क्रमबद्ध करें', 'Loading': 'लोड हो रहा है', 'Error': 'त्रुटि', 'Success': 'सफलता', 'Warning': 'चेतावनी', 'Info': 'जानकारी',
        
        // Login/Register
        'SMART CITY': 'स्मार्ट सिटी', 'Citizen Portal': 'नागरिक पोर्टल', 'Email / Username': 'ईमेल / यूजरनेम', 'Enter your email': 'अपना ईमेल दर्ज करें', 'Password (Optional)': 'पासवर्ड (वैकल्पिक)', 'Leave blank for OTP': 'OTP के लिए खाली छोड़ें', 'Sign In': 'साइन इन', 'New User?': 'नए यूजर?', 'Create Account': 'खाता बनाएं', 'Guest Mode': 'अतिथि मोड', 'Continue as Guest': 'अतिथि के रूप में जारी रखें', 'Track Complaint': 'शिकायत ट्रैक करें',
        
        // Categories
        'Police': 'पुलिस', 'Traffic': 'यातायात', 'Construction': 'निर्माण', 'Water Supply': 'जल आपूर्ति', 'Electricity': 'बिजली', 'Garbage': 'कचरा', 'Road/Pothole': 'सड़क/गड्ढा', 'Drainage': 'जल निकासी', 'Illegal Activity': 'अवैध गतिविधि', 'Transportation': 'परिवहन', 'Cyber Fraud': 'साइबर धोखाधड़ी', 'Other': 'अन्य',
        
        // Police Subcategories
        'Missing Person': 'लापता व्यक्ति', 'Theft': 'चोरी', 'Domestic Violence': 'घरेलू हिंसा', 'Fraud': 'धोखाधड़ी', 'Assault': 'हमला', 'Noise Complaint': 'शोर की शिकायत', 'Drug Activity': 'नशीली दवाओं की गतिविधि', 'Vandalism': 'तोड़फोड़', 'Suspicious Activity': 'संदिग्ध गतिविधि',
        'Theft / Robbery': 'चोरी / डकैती', 'Cyber Crime': 'साइबर अपराध', 'Drug / Narcotics': 'नशीली दवा / मादक पदार्थ', 'Traffic Violation': 'यातायात उल्लंघन', 'Physical Assault': 'शारीरिक हमला', 'Fraud / Scam': 'धोखाधड़ी / जालसाजी', 'Harassment / Threat': 'उत्पीड़न / धमकी', 'Property Damage': 'संपत्ति क्षति', 'Illegal Activity': 'अवैध गतिविधि',
        
        // Traffic Subcategories
        'Signal Jumping': 'सिग्नल जंपिंग', 'Wrong Side Driving': 'गलत साइड ड्राइविंग', 'Overspeeding': 'तेज रफ्तार', 'Illegal Parking': 'अवैध पार्किंग', 'No Helmet / Triple Riding': 'हेलमेट नहीं / तिहरी सवारी', 'No Seatbelt': 'सीटबेल्ट नहीं', 'Drunk Driving': 'नशे में ड्राइविंग', 'Rash / Dangerous Driving': 'लापरवाह / खतरनाक ड्राइविंग', 'Using Mobile While Driving': 'ड्राइविंग के दौरान मोबाइल का उपयोग', 'Heavy Vehicle Violation': 'भारी वाहन उल्लंघन', 'Road Block / Traffic Obstruction': 'सड़क अवरोध / यातायात बाधा', 'Other Traffic Violation': 'अन्य यातायात उल्लंघन',
        
        // Form field labels for specific complaint types
        'Person Name': 'व्यक्ति का नाम', 'Enter person name': 'व्यक्ति का नाम दर्ज करें', 'Age': 'आयु', 'Enter age': 'आयु दर्ज करें', 'Last Seen Location': 'अंतिम बार देखा गया स्थान', 'Enter last seen location': 'अंतिम बार देखा गया स्थान दर्ज करें', 'Last Seen Date': 'अंतिम बार देखा गया दिनांक', 'Physical Description': 'शारीरिक विवरण', 'Additional Details': 'अतिरिक्त विवरण',
        'Person Threatening': 'धमकी देने वाला व्यक्ति', 'Enter person threatening': 'धमकी देने वाला व्यक्ति दर्ज करें', 'Method': 'तरीका', 'Select Method': 'तरीका चुनें', 'Date of Incident': 'घटना की तारीख', 'Frequency of Harassment': 'उत्पीड़न की आवृत्ति', 'Call': 'कॉल', 'Message': 'संदेश', 'In Person': 'व्यक्तिगत रूप से',
        'Scam Type': 'जालसाजी का प्रकार', 'Enter scam type': 'जालसाजी का प्रकार दर्ज करें', 'Amount Lost': 'खोई हुई राशि', 'Enter amount lost': 'खोई हुई राशि दर्ज करें', 'Payment Method': 'भुगतान का तरीका', 'Enter payment method': 'भुगतान का तरीका दर्ज करें', 'Transaction ID': 'लेनदेन पहचान संख्या', 'Enter transaction id': 'लेनदेन पहचान संख्या दर्ज करें',
        'Vehicle Number': 'वाहन नंबर', 'Enter vehicle number': 'वाहन नंबर दर्ज करें', 'Vehicle Type': 'वाहन का प्रकार', 'Road Name': 'सड़क का नाम', 'Location': 'स्थान', 'Date': 'दिनांक', 'Time': 'समय',
        
        // Form fields
        'Submit Complaint': 'शिकायत दर्ज करें', 'Main Category': 'मुख्य श्रेणी', 'Select Category': 'श्रेणी चुनें', 'Subcategory': 'उपश्रेणी', 'Select Subcategory': 'उपश्रेणी चुनें', 'Complaint Title': 'शिकायत का शीर्षक', 'Detailed Description': 'विस्तृत विवरण', 'Location Details': 'स्थान विवरण', 'Auto Detect': 'स्वचालित पहचान', 'Select on Map': 'मैप पर चुनें', 'Manual Entry': 'मैन्युअल एंट्री', 'GPS Coordinates': 'GPS निर्देशांक', 'State': 'राज्य', 'District': 'जिला', 'City': 'शहर', 'Full Name': 'पूरा नाम', 'Phone Number': 'फोन नंबर', 'Email': 'ईमेल', 'Address': 'पता',
        
        // Common values and ALL options
        'Select': 'चुनें', 'Low': 'कम', 'Medium': 'मध्यम', 'High': 'उच्च', 'Small': 'छोटा', 'Large': 'बड़ा', 'Yes': 'हाँ', 'No': 'नहीं', 'Few Minutes': 'कुछ मिनट', '1 Hour': 'एक घंटा', 'Several Hours': 'कई घंटे', 'More Than 1 Day': 'एक दिन से ज्यादा', 'Single House': 'एक घर', 'Building': 'भवन', 'Entire Street': 'पूरी सड़क', 'Entire Area': 'पूरा क्षेत्र', 'Morning': 'सुबह', 'Afternoon': 'दोपहर', 'Evening': 'शाम', 'Night': 'रात', '30 Minutes': '30 मिनट', 'Light Off': 'लाइट बंद', 'Flickering': 'टिमटिमाना', 'Broken Light': 'टूटी लाइट', 'Roadside': 'सड़क किनारे', 'Electric Pole': 'बिजली का खंभा', 'Dangerous': 'खतरनाक', 'Car': 'कार', 'Truck': 'ट्रक', 'Bus': 'बस', 'Two-Wheeler': 'दो पहिया', 'Ongoing': 'चल रहा', 'One-time': 'एक बार'
    },
    'gu': {
        // Common UI elements
        'Submit': 'સબમિટ કરો', 'Cancel': 'રદ કરો', 'Save': 'સેવ કરો', 'Edit': 'સંપાદિત કરો', 'Delete': 'ડિલીટ કરો', 'View': 'જુઓ', 'Back': 'પાછા', 'Next': 'આગળ', 'Previous': 'પહેલાં', 'Close': 'બંધ કરો', 'Search': 'શોધો', 'Filter': 'ફિલ્ટર', 'Sort': 'ક્રમમાં ગોઠવો', 'Loading': 'લોડ થઈ રહ્યું છે', 'Error': 'ભૂલ', 'Success': 'સફળતા', 'Warning': 'ચેતવણી', 'Info': 'માહિતી',
        
        // Login/Register
        'SMART CITY': 'સ્માર્ટ સિટી', 'Citizen Portal': 'નાગરિક પોર્ટલ', 'Email / Username': 'ઈમેઈલ / યુઝરનેમ', 'Enter your email': 'તમારો ઈમેઈલ દાખલ કરો', 'Password (Optional)': 'પાસવર્ડ (વૈકલ્પિક)', 'Leave blank for OTP': 'OTP માટે ખાલી છોડો', 'Sign In': 'સાઈન ઈન', 'New User?': 'નવા યુઝર?', 'Create Account': 'ખાતું બનાવો', 'Guest Mode': 'મહેમાન મોડ', 'Continue as Guest': 'મહેમાન તરીકે ચાલુ રાખો', 'Track Complaint': 'ફરિયાદ ટ્રેક કરો',
        
        // Categories
        'Police': 'પોલીસ', 'Traffic': 'ટ્રાફિક', 'Construction': 'બાંધકામ', 'Water Supply': 'પાણી પુરવઠો', 'Electricity': 'વીજળી', 'Garbage': 'કચરો', 'Road/Pothole': 'રસ્તો/ખાડો', 'Drainage': 'ડ્રેનેજ', 'Illegal Activity': 'ગેરકાયદેસર પ્રવૃત્તિ', 'Transportation': 'પરિવહન', 'Cyber Fraud': 'સાયબર છેતરપિંડી', 'Other': 'અન્ય',
        
        // Police Subcategories
        'Missing Person': 'ગુમ થયેલ વ્યક્તિ', 'Theft': 'ચોરી', 'Domestic Violence': 'ઘરેલું હિંસા', 'Fraud': 'છેતરપિંડી', 'Assault': 'હુમલો', 'Noise Complaint': 'અવાજની ફરિયાદ', 'Drug Activity': 'ડ્રગ પ્રવૃત્તિ', 'Vandalism': 'તોડફોડ', 'Suspicious Activity': 'શંકાસ્પદ પ્રવૃત્તિ',
        'Theft / Robbery': 'ચોરી / લુંટ', 'Cyber Crime': 'સાયબર ક્રાઇમ', 'Drug / Narcotics': 'ડ્રગ / નશીલી દવા', 'Traffic Violation': 'ટ્રાફિક વાયોલેશન', 'Physical Assault': 'શારીરિક હમલો', 'Fraud / Scam': 'છેતરપિંડી / જાલસાજી', 'Harassment / Threat': 'ઉત્પીડન / ધમકી', 'Property Damage': 'સંપત્તિનું નુકસાન', 'Illegal Activity': 'ગેરકાયદેસર પ્રવૃત્તિ',
        
        // Traffic Subcategories
        'Signal Jumping': 'સિગ્નલ જમ્પિંગ', 'Wrong Side Driving': 'ખોટી સાઇડ ડ્રાઇવિંગ', 'Overspeeding': 'તેજ રફ્તાર', 'Illegal Parking': 'ગેરકાયદેસર પાર્કિંગ', 'No Helmet / Triple Riding': 'હેલમેટ નહીં / ટ્રિપલ રાઇડિંગ', 'No Seatbelt': 'સીટબેલ્ટ નહીં', 'Drunk Driving': 'નશામાં ડ્રાઇવિંગ', 'Rash / Dangerous Driving': 'લાપરવાહ / ખતરનાક ડ્રાઇવિંગ', 'Using Mobile While Driving': 'ડ્રાઇવિંગ વખતે મોબાઇલ વાપરવું', 'Heavy Vehicle Violation': 'ભારે વાહન વાયોલેશન', 'Road Block / Traffic Obstruction': 'રોડ બ્લોક / ટ્રાફિક અવરોધ', 'Other Traffic Violation': 'અન્ય ટ્રાફિક વાયોલેશન',
        
        // Form field labels for specific complaint types
        'Person Name': 'વ્યક્તિનું નામ', 'Enter person name': 'વ્યક્તિનું નામ દાખલ કરો', 'Age': 'ઉંમર', 'Enter age': 'ઉંમર દાખલ કરો', 'Last Seen Location': 'છેલ્લે જોવાયેલ સ્થાન', 'Enter last seen location': 'છેલ્લે જોવાયેલ સ્થાન દાખલ કરો', 'Last Seen Date': 'છેલ્લે જોવાયેલ તારીખ', 'Physical Description': 'શારીરિક વર્ણન', 'Additional Details': 'વધારાની વિગતો',
        'Person Threatening': 'ધમકી આપનાર વ્યક્તિ', 'Enter person threatening': 'ધમકી આપનાર વ્યક્તિ દાખલ કરો', 'Method': 'મેથડ', 'Select Method': 'મેથડ પસંદ કરો', 'Date of Incident': 'ઘટનાની તારીખ', 'Frequency of Harassment': 'ઉત્પીડનની આવૃત્તિ', 'Call': 'કોલ', 'Message': 'સંદેશ', 'In Person': 'વ્યક્તિગત રીતે',
        'Scam Type': 'છેતરપિંડીનો પ્રકાર', 'Enter scam type': 'છેતરપિંડીનો પ્રકાર દાખલ કરો', 'Amount Lost': 'ગુમાવેલી રકમ', 'Enter amount lost': 'ગુમાવેલી રકમ દાખલ કરો', 'Payment Method': 'પેમેન્ટ મેથડ', 'Enter payment method': 'પેમેન્ટ મેથડ દાખલ કરો', 'Transaction ID': 'ટ્રાન્સેક્શન આઈડી', 'Enter transaction id': 'ટ્રાન્સેક્શન આઈડી દાખલ કરો',
        'Vehicle Number': 'વાહન નંબર', 'Enter vehicle number': 'વાહન નંબર દાખલ કરો', 'Vehicle Type': 'વાહનનો પ્રકાર', 'Road Name': 'રસ્તાનું નામ', 'Location': 'સ્થાન', 'Date': 'તારીખ', 'Time': 'સમય',
        
        // Form fields
        'Submit Complaint': 'ફરિયાદ દાખલ કરો', 'Main Category': 'મુખ્ય કેટેગરી', 'Select Category': 'કેટેગરી પસંદ કરો', 'Subcategory': 'પેટા કેટેગરી', 'Select Subcategory': 'પેટા કેટેગરી પસંદ કરો', 'Complaint Title': 'ફરિયાદનું શીર્ષક', 'Detailed Description': 'વિસ્તૃત વર્ણન', 'Location Details': 'સ્થાન વિગતો', 'Auto Detect': 'સ્વચાલિત શોધ', 'Select on Map': 'મેપ પર પસંદ કરો', 'Manual Entry': 'મેન્યુઅલ એન્ટ્રી', 'GPS Coordinates': 'GPS કોઓર્ડિનેટ્સ', 'State': 'રાજ્ય', 'District': 'જિલ્લો', 'City': 'શહેર', 'Full Name': 'પૂરું નામ', 'Phone Number': 'ફોન નંબર', 'Email': 'ઇમેઇલ', 'Address': 'સરનામું',
        
        // Common values and ALL options
        'Select': 'પસંદ કરો', 'Low': 'ઓછું', 'Medium': 'મધ્યમ', 'High': 'ઉંચું', 'Small': 'નાનું', 'Large': 'મોટું', 'Yes': 'હા', 'No': 'ના', 'Few Minutes': 'કેટલીક મિનિટ', '1 Hour': 'એક કલાક', 'Several Hours': 'કેટલાક કલાક', 'More Than 1 Day': 'એક દિવસથી વધુ', 'Single House': 'એક ઘર', 'Building': 'બિલ્ડિંગ', 'Entire Street': 'સંપૂર્ણ સ્ટ્રીટ', 'Entire Area': 'સંપૂર્ણ વિસ્તાર', 'Morning': 'સવાર', 'Afternoon': 'દુપહર', 'Evening': 'સાંજ', 'Night': 'રાત', '30 Minutes': '30 મિનિટ', 'Light Off': 'લાઇટ બંધ', 'Flickering': 'ટિમટિમાટ', 'Broken Light': 'હારેલી લાઇટ', 'Roadside': 'રસ્તા કિનારે', 'Electric Pole': 'વીજળીનો ખંભ', 'Dangerous': 'ખતરનાક', 'Car': 'કાર', 'Truck': 'ટ્રક', 'Bus': 'બસ', 'Two-Wheeler': 'બે પહિયા', 'Ongoing': 'ચાલુ', 'One-time': 'એક વાર'
    }
};

// Enhanced translation function for dynamic content
function translatePageGlobal(lang) {
    if (lang === 'en') return;
    const langTranslations = globalTranslations[lang];
    if (!langTranslations) return;
    
    // Translate all text elements
    document.querySelectorAll('*').forEach(element => {
        if (element.children.length === 0) {
            const text = element.textContent.trim();
            if (text && langTranslations[text]) element.textContent = langTranslations[text];
        }
        if (element.placeholder && langTranslations[element.placeholder]) element.placeholder = langTranslations[element.placeholder];
        if (element.tagName === 'OPTION' && langTranslations[element.textContent.trim()]) element.textContent = langTranslations[element.textContent.trim()];
    });
    
    // Translate select options specifically
    document.querySelectorAll('select option').forEach(option => {
        const text = option.textContent.trim();
        if (text && langTranslations[text]) {
            option.textContent = langTranslations[text];
        }
    });
    
    // Translate labels
    document.querySelectorAll('label').forEach(label => {
        const text = label.textContent.trim();
        if (text && langTranslations[text]) {
            label.textContent = langTranslations[text];
        }
    });
}

// Auto-apply translation on page load
document.addEventListener('DOMContentLoaded', function() {
    const savedLang = localStorage.getItem('selectedLanguage') || 'en';
    translatePageGlobal(savedLang);
});