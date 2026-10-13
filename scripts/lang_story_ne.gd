extends RefCounted
## Nepali for the story books, one fighter's book at a time. Keys are the
## exact English lines in story_script.gd. Narration is told the way a
## storybook tells it; Ananta, the master, is spoken of with respect, the
## old classmates call each other तिमी, and students call him तपाईं.

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
	"Every evening, Agasthya drinks his tea at the same roadside stall in the city.": "हरेक साँझ अगस्त्य सहरको उही सडकछेउको चिया पसलमा चिया पिउँछ।",
	"The boy who washes the glasses wants to be a doctor. The tea-maker's daughter paints on old newspapers.": "गिलास धुने केटो डाक्टर बन्न चाहन्छ। चिया पकाउने साहुजीकी छोरी पुराना पत्रिकामा चित्र कोर्छे।",
	"The porter on the next bench once ran for his district. Now he carries gas cylinders up four floors.": "छेउको बेन्चमा बस्ने भरिया कुनै बेला आफ्नो जिल्लाका लागि दौडिएको थियो। अहिले ऊ ग्यास सिलिन्डर बोकेर चार तला उक्लन्छ।",
	"Every one of them has a dream. And not one of them can afford it.": "यिनीहरू सबैको एउटा सपना छ। तर कसैसँग पनि त्यो पूरा गर्ने पैसा छैन।",
	"Guruji used to say a fist is only as good as what it protects. I never knew what mine was for.": "गुरुजी भन्नुहुन्थ्यो, मुठीको मोल त्यसले जोगाउने कुराले तय गर्छ। मेरो मुठी केका लागि हो, मैले कहिल्यै बुझिनँ।",
	"Then the letter came. The same one, sealed, to all six of the master's old students.": "अनि एउटा चिठी आयो। छाप लगाइएको उही चिठी, गुरुका छ जना पुराना चेलाहरू सबैलाई।",
	"AN INVITATION": "एउटा निम्तो",
	"ANANTA": "अनन्त",
	"A TOURNAMENT OF MASTERS": "महारथीहरूको प्रतियोगिता",
	"\"The strongest shall claim a reward of NPR 5 crore. The final victor shall discover the whereabouts of the missing Master.\"": "\"सबैभन्दा बलियोले ५ करोड रुपैयाँ पुरस्कार पाउनेछ। अन्तिम विजेताले हराइरहनुभएका गुरुको ठेगाना थाहा पाउनेछ।\"",
	"Five crore. A doctor. A painter. A runner. That's what my hands are for.": "पाँच करोड। एउटा डाक्टर। एउटी चित्रकार। एउटा धावक। मेरा हात यसैका लागि रहेछन्।",
	# Vajraveer
	"Agasthya... you were always the brave one. I'm only here to stop being scared.": "अगस्त्य... साहसी त सधैँ तिमी नै थियौ। म त आफ्नो डर हटाउन मात्र यहाँ आएको हुँ।",
	"Then don't be scared of me. Fight me like you mean it.": "त्यसो भए मसँग नडराऊ। साँच्चै मन लगाएर लड।",
	"I didn't run. That's... a first.": "म भागिनँ। यो त... पहिलो पटक हो।",
	"Keep that. It's worth more than winning.": "यसलाई साँचेर राख। यो जितभन्दा धेरै मूल्यवान् छ।",
	"Sorry... I think I just got brave.": "माफ गर... म भर्खरै साहसी भएँ जस्तो छ।",
	# Kri
	"The Flash Hammer! Fighting for strangers now? Very noble. Very loud of you.": "बिजुली हथौडा! अब अपरिचितका लागि लड्दै छौ? कति महान्! कति देखावटी!",
	"They're not strangers, Kri. They're my neighbours.": "उनीहरू अपरिचित होइनन्, क्रि। मेरा छिमेकी हुन्।",
	"Fine. Buy your neighbours a good dinner on me.": "ठिकै छ। मेरो तर्फबाट छिमेकीहरूलाई राम्रो खाना खुवाइदेऊ।",
	"Noble AND slow? Again!": "महान् पनि, ढिलो पनि? फेरि!",
	# Anug
	"You want the money for other people too, don't you? I can see it.": "तिमीलाई पनि त्यो पैसा अरूकै लागि चाहिएको छ, होइन? मैले देखिरहेको छु।",
	"Every kid with a dream and no money. Same as yours, keeper.": "सपना भएका तर पैसा नभएका हरेक केटाकेटीका लागि। तिम्रो जस्तै, गोलकिपर।",
	"Then only one of us can carry it. Come on.": "त्यसो भए हामीमध्ये एक जनाले मात्र यो भार बोक्न सक्छ। आऊ।",
	"Carry it for both of us, then.": "त्यसो भए हामी दुवैका लागि बोक।",
	"Saved. Your heart's right. Your guard's not.": "सेभ! तिम्रो मन सही छ, तर बचाउ सही छैन।",
	# Mahabali
	"Ah, the saviour of the tea stall. Did you bring me a cup?": "ओहो, चिया पसलका उद्धारक! मेरा लागि एक कप ल्यायौ कि?",
	"Get up and fight, Mahabali. For once in your life.": "उठ र लड, महाबली। जिन्दगीमा एक पटक त।",
	"For once in my life? Now you've made it personal.": "जिन्दगीमा एक पटक? अब त कुरा व्यक्तिगत भयो।",
	"Good. Now go and change some lives. I'll watch. Lying down, probably.": "राम्रो। अब जाऊ, केही जिन्दगी बदल। म हेर्छु। सायद पल्टिएरै।",
	"See? Even I get up sometimes. Your turn.": "देख्यौ? म पनि कहिलेकाहीँ उठ्छु। अब तिम्रो पालो।",
	# Sarvochcha
	"My family needs this, Agasthya.": "मेरो परिवारलाई यो चाहिएको छ, अगस्त्य।",
	"So does mine. A whole street of it.": "मेरो परिवारलाई पनि। पूरै एउटा गल्ली भरिको परिवार।",
	"...Then make it count. For all of them.": "...त्यसो भए यसलाई सार्थक बनाऊ। ती सबैका लागि।",
	"Too fast for your own good. Breathe, and come again.": "तिमी आफ्नै हितभन्दा बढी हतारिन्छौ। सास फेर, अनि फेरि आऊ।",
	# Ananta
	"The final opponent waits. And Agasthya knows him at once.": "अन्तिम प्रतिद्वन्द्वी पर्खिरहनुभएको छ। अगस्त्यले उहाँलाई तुरुन्तै चिन्छ।",
	"Guruji. All these years... and you were the one who called us.": "गुरुजी! यत्तिका वर्ष... अनि हामीलाई बोलाउने तपाईं नै हुनुहुँदोरहेछ।",
	"Show me what your hands are for, Agasthya.": "देखाऊ, तिम्रा हात केका लागि हुन्, अगस्त्य।",
	"Fast. Not yet wise. Again.": "छिटो छौ, तर अझै बुद्धिमान् भएनौ। फेरि।",
	# Finale
	"When it was over, Ananta told him the truth: the final he lost, the shame, the years in hiding, the five crore he could not bring himself to spend.": "सबै सकिएपछि अनन्तले उसलाई सत्य सुनाउनुभयो: आफूले हारेको फाइनल, त्यो लाज, लुकेर बिताएका वर्षहरू, र खर्च गर्न मन नमानेको त्यो पाँच करोड।",
	"It was meant for whichever of you would use it best.": "यो तिमीहरूमध्ये जसले सबैभन्दा राम्रो सदुपयोग गर्छ, उसैका लागि थियो।",
	"Then it isn't mine. It belongs to a doctor, a painter and a runner who never got the chance.": "त्यसो भए यो मेरो होइन। यो कहिल्यै मौका नपाएका एउटा डाक्टर, एउटी चित्रकार र एउटा धावकको हो।",
	"I taught you to hit fast. You learned what to hit for. That I never taught.": "मैले तिमीलाई छिटो हान्न सिकाएँ। केका लागि हान्ने, त्यो तिमी आफैँ सिक्यौ। त्यो मैले कहिल्यै सिकाइनँ।",
	"A month later, at the same roadside stall, a boy opened his first medical book.": "एक महिनापछि, उही सडकछेउको चिया पसलमा, एउटा केटाले आफ्नो जीवनको पहिलो चिकित्साशास्त्रको किताब खोल्यो।",
}
