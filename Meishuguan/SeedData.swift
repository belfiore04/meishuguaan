import Foundation

/// 模拟展品。用于让 app 启动后展厅就有内容看，不用先拍真书走完整链路。
/// 真用 app 时也无妨——拍真书生成的展品会 append 到这些后面。
enum SeedData {
    static func makeMockExhibits() -> [Exhibit] {
        [
            Exhibit(
                book: Book(
                    title: "看不见的城市",
                    author: "卡尔维诺",
                    brief: "马可波罗向忽必烈讲述他途经的虚构城市，每座城市都是想象与记忆的折叠。"
                ),
                noteText: """
                马可波罗对忽必烈讲述他途经的城市，每一座都是想象的产物。有些城市像一个被反复折叠的梦，每次铺开都不同；有些城市的居民只在夜里出现。

                读到一半才意识到，他描述的所有城市，都是威尼斯。原来人在异乡讲述时，讲的永远是故乡。

                那种"城市并不是它自己，而是想要它成为的样子"——这一句留下来很久。
                """,
                objectPrompt: "a single small ornate column resting on white background, museum quality 3D render",
                fallbackSymbol: "building.columns"
            ),
            Exhibit(
                book: Book(
                    title: "设计中的设计",
                    author: "原研哉",
                    brief: "无印良品艺术总监原研哉关于「白」和「空」的设计哲学。"
                ),
                noteText: """
                白不是颜色，是状态。原研哉说"无"不等于没有，而是一种可能性的容器。

                想到自己屋里那面没挂任何东西的墙，原来不是没设计、是设计成了等待。

                日本人对"间"的处理——画面里留白的那一块，比画上去的东西更重要。这件事我以前觉得是审美，今天明白其实是一种克制：相信看的人有能力自己填空。
                """,
                objectPrompt: "a single sheet of white paper folded once, soft shadow, minimalist museum lighting",
                fallbackSymbol: "square.dashed"
            ),
            Exhibit(
                book: Book(
                    title: "维特根斯坦的拨火棒",
                    author: "Edmonds & Eidinow",
                    brief: "1946 年剑桥道德科学俱乐部那个晚上，维特根斯坦与波普尔的十分钟之争。"
                ),
                noteText: """
                1946 年剑桥那个晚上，波普尔和维特根斯坦在 10 分钟里吵到几乎动手。一根拨火棒，三十年后还有人在追究那天到底发生了什么。

                有些人争论的不是观点，是脾气。两个犹太裔哲学家、维也纳同乡、谁也不让谁——那一晚之后，他们再没见过面。

                读完最想知道的反而不是真相，而是：罗素当晚坐在沙发上，一句话都没说。他在想什么？
                """,
                objectPrompt: "a single iron poker leaning against an invisible wall, dramatic single light, monochrome",
                fallbackSymbol: "flame"
            )
        ]
    }
}
