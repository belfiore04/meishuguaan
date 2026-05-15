import Foundation

/// 模拟展品。让 app 启动后展厅就有内容看，不用先走完整链路。
/// 首次启动写盘一次；之后只要 index.json 存在就不再注入。
enum SeedData {
    static func makeMockExhibits() -> [Exhibit] {
        [makeCalvino(), makeHara(), makePoker()]
    }

    private static func makeCalvino() -> Exhibit {
        let end = Date().addingTimeInterval(-3 * 24 * 3600 - 1800)
        let start = end.addingTimeInterval(-24 * 60)
        return Exhibit(
            book: Book(
                title: "看不见的城市",
                author: "卡尔维诺",
                brief: "马可波罗向忽必烈讲述他途经的虚构城市，每座城市都是想象与记忆的折叠。"
            ),
            objectName: "重影",
            noteText: """
            这次阅读绕着一个矛盾打转——他读马可波罗描述了五十多座虚构的城市，却越读越觉得它们彼此不像陌生人。

            读到第九节他停了很久，反复念出"记忆里的城市"那一段，说了一句「这些不是城市，是同一个城市被反复折回。」

            最后他没有合上书。他注意到这些城市彼此互为重影，转过头说，可能读他自己的人生时也是这样。
            """,
            objectPrompt: "a single small ornate column with a faint reflection on white background, museum quality 3D render",
            fallbackSymbol: "building.columns",
            messages: [
                ChatMessage(role: .assistant, text: "看到了。\n你慢慢翻，想说什么再说。"),
                ChatMessage(role: .user, text: "他写的这些城市，怎么读着都像同一个？"),
                ChatMessage(role: .assistant, text: "卡尔维诺自己后来说，他写的所有城市，都是威尼斯。"),
                ChatMessage(role: .user, text: "哦那他在装作迷路。"),
                ChatMessage(role: .assistant, text: "或者他知道自己永远走不出来。"),
                ChatMessage(role: .user, text: "这些不是城市，是同一个城市被反复折回。"),
                ChatMessage(role: .assistant, text: "嗯。读他自己的人生时可能也是。")
            ],
            startedAt: start,
            generatedAt: end
        )
    }

    private static func makeHara() -> Exhibit {
        let end = Date().addingTimeInterval(-1 * 24 * 3600 - 7200)
        let start = end.addingTimeInterval(-32 * 60)
        return Exhibit(
            book: Book(
                title: "设计中的设计",
                author: "原研哉",
                brief: "无印良品艺术总监原研哉关于「白」和「空」的设计哲学。"
            ),
            objectName: "白",
            noteText: """
            他一开始把"白"读成颜色。读到第三章意识到原研哉说的是状态——一种容许尚未发生的可能性的状态。

            中段他绕回到自己屋里那面没挂任何东西的墙，问了一句「那如果一直空着算不算设计？」这个问题没有被回答。

            最后他停在原研哉写"无"的一段，说「我以为是留白，原来是等待。」
            """,
            objectPrompt: "a single sheet of folded white paper resting on white background, soft shadow, minimalist museum lighting",
            fallbackSymbol: "square.dashed",
            messages: [
                ChatMessage(role: .assistant, text: "看到了。\n你慢慢翻，想说什么再说。"),
                ChatMessage(role: .user, text: "他这里说白不是颜色而是一种状态，能再帮我理解一下吗"),
                ChatMessage(role: .assistant, text: "他不是讲色卡，是讲什么都还没发生的那种状态——一种被刻意留住的可能性。"),
                ChatMessage(role: .user, text: "那我家那面没挂任何东西的墙，到底算我懒还是有设计感"),
                ChatMessage(role: .assistant, text: "如果你每次走过它都会停一秒，那就是设计。"),
                ChatMessage(role: .user, text: "我以为是留白，原来是等待。")
            ],
            startedAt: start,
            generatedAt: end
        )
    }

    private static func makePoker() -> Exhibit {
        let end = Date().addingTimeInterval(-3600 - 600)
        let start = end.addingTimeInterval(-19 * 60)
        return Exhibit(
            book: Book(
                title: "维特根斯坦的拨火棒",
                author: "Edmonds & Eidinow",
                brief: "1946 年剑桥道德科学俱乐部那个晚上，维特根斯坦与波普尔的十分钟之争。"
            ),
            objectName: "沉默",
            noteText: """
            他在乎的不是 1946 年那个晚上究竟发生了什么——而是这之后三十年，为什么还有人在追问。

            中段他说「两个犹太裔哲学家、维也纳同乡、谁也不让谁，这场架本就调停不了。」

            读到最后他把目光从波普尔和维特根斯坦身上挪开，落到了沙发上那个一句话都没说的罗素。他问：那一晚罗素在想什么。
            """,
            objectPrompt: "a single iron poker leaning against an invisible wall, dramatic single light, monochrome museum render",
            fallbackSymbol: "flame",
            messages: [
                ChatMessage(role: .assistant, text: "看到了。\n你慢慢翻，想说什么再说。"),
                ChatMessage(role: .user, text: "他们那晚到底是怎么吵起来的？"),
                ChatMessage(role: .assistant, text: "波普尔讲到道德哲学，维特根斯坦举起壁炉边的拨火棒说\"举一个道德原则的例子\"。然后两个人就开始僵。"),
                ChatMessage(role: .user, text: "他们俩都是脾气大的人。"),
                ChatMessage(role: .assistant, text: "维也纳同乡，又都犹太裔，从家乡带出来的火气没处放。"),
                ChatMessage(role: .user, text: "罗素当晚一句话没说？"),
                ChatMessage(role: .assistant, text: "对。坐在沙发上看着。后来谁也没问过他在想什么。")
            ],
            startedAt: start,
            generatedAt: end
        )
    }
}
