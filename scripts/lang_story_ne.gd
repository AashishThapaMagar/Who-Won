extends RefCounted
## Nepali for the story books, one fighter's book at a time. Keys are the
## exact English lines in story_script.gd. Narration is told the way a
## storybook tells it. Guru Ananta is everyone's elder: anyone speaking to
## him says हजुर (with -नुहुन्छ verbs), the narration speaks of him with
## honorifics (उहाँले ...नुभयो), and he calls his old students तिमी. The six
## classmates call each other तिमी.

const STRINGS := {
	# ── Shared: fighter titles, chapter cards ──
	"THE LAST LINE": "अन्तिम पर्खाल",
	"THE FLASH HAMMER": "बिजुली हथौडा",
	"THE IRON GRIP": "फलामे पकड",
	"THE ENDLESS RUSH": "अथक आँधी",
	"THE LOUD THUNDER": "गर्जने मेघ",
	"THE SPIRAL": "भुमरी",
	"%s FALLS": "%s पराजित",
	"%s   /   CHAMPION": "%s   /   विजेता",
	"THE END.": "समाप्त।",

	# ── Agasthya: The Fastest Hands ──
	"THE FASTEST HANDS": "सबैभन्दा छिटा हात",
	"THE STORY OF AGASTHYA": "अगस्त्यको कथा",
	"A BETTER CHANGE": "एउटा असल परिवर्तन",
	"Every evening, Agasthya drinks his tea at the same roadside stall in the city.": "हरेक साँझ अगस्त्य सहरको सडकछेउमा रहेको उही चिया पसलमा चिया पिउँछ।",
	"The boy who washes the glasses wants to be a doctor. The tea-maker's daughter paints on old newspapers.": "गिलास धुने केटो डाक्टर बन्न चाहन्छ। चिया पकाउने साहुजीकी छोरी पुराना पत्रिकामा चित्र कोर्छे।",
	"The porter on the next bench once ran for his district. Now he carries gas cylinders up four floors.": "छेउको बेन्चमा बस्ने भरियाले कुनै बेला आफ्नो जिल्लाका तर्फबाट दौडमा भाग लिएको थियो। अहिले ऊ ग्यास सिलिन्डर बोकेर चार तला उक्लन्छ।",
	"Every one of them has a dream. And not one of them can afford it.": "यिनीहरू सबैका आ-आफ्ना सपना छन्। तर कसैसँग पनि ती पूरा गर्ने पैसा छैन।",
	"Guruji used to say a fist is only as good as what it protects. I never knew what mine was for.": "गुरुजी भन्नुहुन्थ्यो, मुठीको मूल्य त्यसले केको रक्षा गर्छ भन्नेमा हुन्छ। मेरो मुठी केका लागि हो, मैले कहिल्यै बुझिनँ।",
	"Then the letter came. The same one, sealed, to all six of the master's old students.": "अनि एक दिन चिठी आयो। गुरुका छ जना पुराना चेलाहरू सबैलाई छाप लगाइएको एउटै चिठी।",
	"AN INVITATION": "एउटा निम्तो",
	"ANANTA": "अनन्त",
	"A TOURNAMENT OF MASTERS": "महारथीहरूको प्रतियोगिता",
	"\"The strongest shall claim a reward of NPR 5 crore. The final victor shall discover the whereabouts of the missing Master.\"": "\"सबैभन्दा बलियो योद्धाले रु. ५ करोड पुरस्कार पाउनेछ। अन्तिम विजेताले बेपत्ता हुनुभएका गुरुको ठेगाना पत्ता लगाउनेछ।\"",
	"Five crore. A doctor. A painter. A runner. That's what my hands are for.": "पाँच करोड। एउटा डाक्टर। एउटी चित्रकार। एउटा धावक। मेरा हात यसैका लागि रहेछन्।",
	# Vajraveer
	"Agasthya... you were always the brave one. I'm only here to stop being scared.": "अगस्त्य... साहसी त सधैँ तिमी नै थियौ। म त आफ्नो डर हटाउन मात्र यहाँ आएको हुँ।",
	"Then don't be scared of me. Fight me like you mean it.": "त्यसो भए मदेखि नडराऊ। मन लगाएर, पूरा जोडले लड।",
	"I didn't run. That's... a first.": "म भागिनँ। यो त... पहिलो पटक हो।",
	"Keep that. It's worth more than winning.": "यो साहस साँचेर राख। यो जितभन्दा पनि मूल्यवान् छ।",
	"Sorry... I think I just got brave.": "माफ गर... म भर्खरै साहसी भएँ जस्तो लाग्छ।",
	# Kri
	"The Flash Hammer! Fighting for strangers now? Very noble. Very loud of you.": "बिजुली हथौडा! अब अपरिचितहरूका लागि लड्दै छौ? कति महान्! कति देखावटी!",
	"They're not strangers, Kri. They're my neighbours.": "उनीहरू अपरिचित होइनन्, क्रि। मेरा छिमेकी हुन्।",
	"Fine. Buy your neighbours a good dinner on me.": "ठिकै छ। मेरो तर्फबाट छिमेकीहरूलाई मीठो खाना खुवाइदेऊ।",
	"Noble AND slow? Again!": "महान् पनि, सुस्त पनि? फेरि आऊ!",
	# Anug
	"You want the money for other people too, don't you? I can see it.": "तिमीलाई पनि त्यो पैसा अरूका लागि नै चाहिएको हो, होइन? म देख्न सक्छु।",
	"Every kid with a dream and no money. Same as yours, keeper.": "सपना भएका तर पैसा नभएका हरेक केटाकेटीका लागि। तिम्रो जस्तै, गोलकिपर।",
	"Then only one of us can carry it. Come on.": "त्यसो भए यो भार हामीमध्ये एक जनाले मात्र बोक्न पाउँछ। आऊ।",
	"Carry it for both of us, then.": "त्यसो भए हामी दुवैको भार तिमी नै बोक।",
	"Saved. Your heart's right. Your guard's not.": "सेभ! तिम्रो नियत सही छ, तर बचाउ कमजोर छ।",
	# Mahabali
	"Ah, the saviour of the tea stall. Did you bring me a cup?": "ओहो, चिया पसलका रक्षक आइपुगे! मेरा लागि एक कप चिया ल्यायौ कि?",
	"Get up and fight, Mahabali. For once in your life.": "उठ र लड, महाबली। जिन्दगीमा एक पटक त गम्भीर भएर लड।",
	"For once in my life? Now you've made it personal.": "जिन्दगीमा एक पटक? अब त कुरा इज्जतको भयो।",
	"Good. Now go and change some lives. I'll watch. Lying down, probably.": "शाबास। अब जाऊ, केही मान्छेको जिन्दगी बदल। म हेरिरहन्छु, सायद पल्टिएरै।",
	"See? Even I get up sometimes. Your turn.": "देख्यौ? म पनि कहिलेकाहीँ उठ्छु। अब तिम्रो पालो।",
	# Sarvochcha
	"My family needs this, Agasthya.": "मेरो परिवारलाई यो पैसा चाहिएको छ, अगस्त्य।",
	"So does mine. A whole street of it.": "मेरो परिवारलाई पनि। मेरो परिवार त पूरै एउटा गल्ली हो।",
	"...Then make it count. For all of them.": "...त्यसो भए यसलाई सार्थक बनाऊ। ती सबैका लागि।",
	"Too fast for your own good. Breathe, and come again.": "तिमी आवश्यकताभन्दा बढी हतार गर्छौ। सास फेर, अनि फेरि आऊ।",
	# Ananta
	"The final opponent waits. And Agasthya knows him at once.": "अन्तिम प्रतिद्वन्द्वी पर्खिरहनुभएको छ। अगस्त्यले उहाँलाई एकै नजरमा चिन्छ।",
	"Guruji. All these years... and you were the one who called us.": "गुरुजी! यत्तिका वर्ष... अनि हामीलाई बोलाउने हजुर नै हुनुहुँदोरहेछ।",
	"Show me what your hands are for, Agasthya.": "अगस्त्य, देखाऊ त, तिम्रा हात केका लागि हुन्।",
	"Fast. Not yet wise. Again.": "छिटो त छौ, तर अझै विवेकी भइसकेका छैनौ। फेरि आऊ।",
	# Finale
	"When it was over, Ananta told him the truth: the final he lost, the shame, the years in hiding, the five crore he could not bring himself to spend.": "लडाइँ सकिएपछि अनन्त गुरुले उसलाई सबै सत्य सुनाउनुभयो: उहाँले हार्नुभएको त्यो फाइनल, त्यसपछिको लाज, लुकेर बिताउनुभएका वर्षहरू, र खर्च गर्न मन नमानेको त्यो पाँच करोड।",
	"It was meant for whichever of you would use it best.": "यो तिमीहरूमध्ये जसले सबैभन्दा राम्रो सदुपयोग गर्छ, उसैका लागि थियो।",
	"Then it isn't mine. It belongs to a doctor, a painter and a runner who never got the chance.": "त्यसो भए हजुर, यो मेरो होइन। यो कहिल्यै मौका नपाएका एउटा डाक्टर, एउटी चित्रकार र एउटा धावकको हो।",
	"I taught you to hit fast. You learned what to hit for. That I never taught.": "मैले तिमीलाई छिटो हान्न सिकाएँ। तर केका लागि हान्ने भन्ने कुरा तिमीले आफैँ सिक्यौ। त्यो त मैले कहिल्यै सिकाइनँ।",
	"A month later, at the same roadside stall, a boy opened his first medical book.": "एक महिनापछि, सडकछेउको त्यही चिया पसलमा, गिलास धुने त्यो केटाले आफ्नो पहिलो चिकित्साशास्त्रको किताब खोल्यो।",
}
