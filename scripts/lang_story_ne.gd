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

	# ── Mahabali: The Lazy Giant ──
	"THE LAZY GIANT": "अल्छी पहलमान",
	"THE STORY OF MAHABALI": "महाबलीको कथा",
	"GET UP, MAHABALI": "उठ, महाबली",
	"In his village, everyone knows Mahabali. Mostly lying on a rope bed under the pipal tree.": "गाउँमा महाबलीलाई सबैले चिन्छन्। प्रायः पीपलको रूखमुनि खाटमा पल्टिरहेको।",
	"He is the strongest of the master's six students. And the laziest.": "गुरुका छ जना चेलामध्ये ऊ सबैभन्दा बलियो हो। अनि सबैभन्दा अल्छी पनि।",
	"Work? Today? The tree is giving me shade. It would be rude to leave.": "काम? आज? रूखले मलाई छहारी दिइरहेको छ। छोडेर जानु त अशिष्टता हुन्छ।",
	"But his teasing has a habit of changing lives. The boy he called 'too slow' now runs for the district. The girl he said 'could never pass' topped her exams.": "तर उसको जिस्क्याइले मान्छेको जीवन बदल्ने बानी छ। जसलाई उसले 'ज्यादै सुस्त' भनेको थियो, त्यो केटो अहिले जिल्लाका लागि दौडन्छ। जसलाई 'कहिल्यै पास हुँदिनस्' भनेको थियो, त्यो केटीले परीक्षामा सबैभन्दा धेरै अङ्क ल्याई।",
	"Me? I didn't do anything. I just talk too much.": "म? मैले केही गरेको छैन। म त धेरै बोल्छु मात्र।",
	"Then the letter came, and for the first time in years, Mahabali sat up.": "अनि चिठी आयो, र वर्षौँपछि पहिलो पटक महाबली उठेर बस्यो।",
	"Guruji's whereabouts... and all my old friends, in one place. Fighting.": "गुरुजीको ठेगाना... अनि मेरा सबै पुराना साथी, एकै ठाउँमा। लड्दै।",
	"Everyone I've ever pushed has climbed higher than me. Maybe it's time I pushed myself.": "मैले घचघच्याएका सबै मभन्दा माथि पुगे। अब सायद आफैँलाई घचघच्याउने बेला आयो।",
	# Vajraveer
	"Vajraveer! Out of your shell! Who are you and what have you done with my shy friend?": "वज्रवीर! खोलबाट बाहिर निस्कियौ! को हौ तिमी, र मेरो लजालु साथीलाई के गर्‍यौ?",
	"I'm facing my fears today. You're the first one.": "आज म आफ्नो डरको सामना गर्दै छु। पहिलो डर तिमी नै हौ।",
	"Wonderful. I'll be very scary, then.": "वाह! त्यसो भए म निकै डरलाग्दो बन्छु।",
	"You came out. That's the real win. I just got the points.": "तिमी खोलबाट बाहिर निस्कियौ। असली जित त्यही हो। मैले त अङ्क मात्र पाएँ।",
	"You let me win... didn't you?": "तिमीले मलाई जानाजान जिताइदियौ... होइन?",
	# Anug
	"You, standing? This tournament really is special.": "तिमी, उभिएको? यो प्रतियोगिता साँच्चै विशेष रहेछ।",
	"Don't get used to it, keeper.": "बानी नपार, गोलकिपर।",
	"Lazy, my foot. You've been hiding this.": "अल्छी रे, कहाँको! तिमीले त यो सब लुकाएर राखेका रहेछौ।",
	"Nothing gets past me. Not even you, giant.": "मलाई छलेर कोही जान सक्दैन। तिमी पनि होइन, पहलमान।",
	# Kri
	"The only man in Nepal louder than me!": "नेपालमा मभन्दा ठूलो स्वरमा बोल्ने एक्लो मान्छे!",
	"Louder AND stronger. Let's settle the first one quickly.": "स्वर पनि ठूलो, बल पनि धेरै। स्वरको फैसला चाँडै गरौँ।",
	"Fine! But I'm still funnier.": "ठिकै छ! तर रमाइलो त म नै बढी छु।",
	"Too much talking, Mahabali. Not enough punching.": "बोली धेरै, मुक्का थोरै, महाबली।",
	# Agasthya
	"You actually want this? I thought you'd sleep through the whole tournament.": "तिमीलाई साँच्चै यो चाहिएको हो? मलाई त तिमी पूरै प्रतियोगिता सुतेरै बिताउँछौ जस्तो लागेको थियो।",
	"I tried. The fights kept waking me up.": "कोसिस त गरेँ। लडाइँहरूले बारम्बार ब्युँझाइदिए।",
	"Use it well, giant. You always told us to.": "राम्रोसँग प्रयोग गर, पहलमान। तिमीले नै सधैँ हामीलाई त्यसो भन्थ्यौ।",
	"Too slow, Mahabali. You'd tease anyone else for that.": "ज्यादै सुस्त, महाबली। अरू कोही भएको भए तिमी जिस्क्याउँथ्यौ।",
	# Sarvochcha
	"Two old friends. One fight. Neither can afford to lose.": "दुई पुराना साथी। एउटै लडाइँ। हार दुवैलाई महँगो पर्छ।",
	"THE FIGHT BETWEEN FRIENDS": "साथीहरूबीचको लडाइँ",
	"BROTHERS IN TRAINING": "तालिमका दाजुभाइ",
	"It's been a long time, hasn't it?": "धेरै समय भयो, होइन?",
	"Too long. And you still drop your left hand when you're tired. I'll be kind and only use it a little.": "धेरै नै भयो। अनि थाकेपछि तिमी अझै देब्रे हात खसाल्छौ। म दया गरेर त्यसको फाइदा थोरै मात्र उठाउँछु।",
	"Get up, brother. You taught me to stop being lazy just by never stopping.": "उठ, साथी। कहिल्यै नरोकिएर तिमीले मलाई अल्छी नहुन सिकायौ।",
	"...I'll see you again, my friend.": "...फेरि भेटौँला, मेरो साथी।",
	"Guruji never let us stop halfway. Neither will I.": "गुरुजीले हामीलाई कहिल्यै आधा बाटोमा रोकिन दिनुभएन। म पनि दिन्नँ।",
	# Ananta
	"The last opponent waits in silence. Mahabali stops joking.": "अन्तिम प्रतिद्वन्द्वी चुपचाप पर्खिरहनुभएको छ। महाबलीको ठट्टा रोकिन्छ।",
	"...Guruji.": "...गुरुजी।",
	"The strongest of my students. Finally standing up.": "मेरा चेलामध्ये सबैभन्दा बलियो। आखिर उठ्यौ।",
	"You always said I'd only fight when it really mattered. It matters now.": "हजुरले सधैँ भन्नुहुन्थ्यो, साँच्चै महत्त्वपूर्ण बेलामा मात्र म लड्छु। अहिले त्यो बेला आएको छ।",
	"Strength without effort. Again, and mean it.": "मिहिनेतबिनाको बल। फेरि आऊ, मन लगाएर।",
	# Finale
	"When it was over, the master told him the truth: the final he lost, the shame, the years in hiding, the five crore saved for one of his students.": "लडाइँ सकिएपछि गुरुले उसलाई सबै सत्य सुनाउनुभयो: उहाँले हार्नुभएको त्यो फाइनल, त्यसपछिको लाज, लुकेर बिताउनुभएका वर्षहरू, र आफ्नै कुनै चेलाका लागि जोगाएर राख्नुभएको पाँच करोड।",
	"You lost one fight and hid for years. I won nothing and lay under a tree for years. We're quite a pair, Guruji.": "हजुरले एउटा लडाइँ हार्नुभयो र वर्षौँ लुक्नुभयो। मैले केही जितिनँ र वर्षौँ रूखमुनि पल्टिएँ। हामी त गजबको जोडी रहेछौँ, गुरुजी।",
	"And yet everyone you teased became something. You were teaching all along.": "तैपनि तिमीले जिस्क्याएका सबै केही न केही बने। तिमी त सधैँ सिकाइरहेका रहेछौ।",
	"Then let's build a training hall. I'll do the teasing. You do the teaching.": "त्यसो भए एउटा तालिमशाला बनाऔँ। जिस्क्याउने काम मेरो, सिकाउने काम हजुरको।",
	"The rope bed under the pipal tree stayed empty after that. Mostly.": "त्यसपछि पीपलमुनिको त्यो खाट खाली रह्यो। प्रायः।",
}
